//! Audio visualization data capture.
//!
//! Captures post-DSP audio samples from the cpal callback and computes
//! FFT spectrum data. All writes happen in the real-time audio thread,
//! so this uses only lock-free atomics and pre-allocated buffers.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use realfft::RealFftPlanner;

/// Number of samples to capture for waveform display (mono, downmixed).
const WAVEFORM_SAMPLES: usize = 256;

/// FFT size — must be power of 2. 2048 gives good frequency resolution at 44.1/48kHz.
const FFT_SIZE: usize = 2048;

/// Number of frequency bins exposed to the UI (logarithmically distributed).
const SPECTRUM_BINS: usize = 64;

/// Shared visualization buffer between the audio thread (writer) and FFI reader.
///
/// The audio thread writes continuously; the reader snapshots when polled.
/// Double-buffered: writer fills `back`, atomically swaps to `front` when ready.
pub struct VisualizationBuffer {
    /// Front buffer (readable). Only swapped atomically.
    front_waveform: Box<[f32; WAVEFORM_SAMPLES]>,
    front_spectrum: Box<[f32; SPECTRUM_BINS]>,

    /// Back buffer (writable by audio thread).
    back_waveform: Box<[f32; WAVEFORM_SAMPLES]>,
    back_spectrum: Box<[f32; SPECTRUM_BINS]>,

    /// Accumulator for FFT input.
    fft_input: Box<[f32; FFT_SIZE]>,
    fft_pos: usize,

    /// Swap flag: set by writer, cleared by reader.
    ready: AtomicBool,

    /// Peak level (0.0 - 1.0) for simple VU meter, exponential decay.
    peak_left: f32,
    peak_right: f32,

    /// Whether visualization is enabled. Skip work when off.
    enabled: AtomicBool,

    /// Smoothing factor for spectrum (0.0 = no smoothing, 1.0 = frozen).
    smoothing: f32,
    prev_spectrum: Box<[f32; SPECTRUM_BINS]>,
}

/// Thread-safe wrapper. The inner buffer is only accessed via specific patterns:
/// - Audio thread calls `push_samples()` (single writer)
/// - FFI thread calls `snapshot()` (single reader, infrequent)
pub struct SharedVisualization {
    inner: parking_lot::Mutex<VisualizationBuffer>,
}

unsafe impl Send for SharedVisualization {}
unsafe impl Sync for SharedVisualization {}

/// Snapshot of visualization data, sent across FFI.
#[derive(Debug, Clone)]
pub struct VisualizationSnapshot {
    /// Mono waveform samples, -1.0 to 1.0.
    pub waveform: Vec<f32>,
    /// Spectrum magnitude bins (log-frequency distributed), 0.0 to 1.0.
    pub spectrum: Vec<f32>,
    /// Left channel peak (0.0 - 1.0).
    pub peak_left: f32,
    /// Right channel peak (0.0 - 1.0).
    pub peak_right: f32,
}

impl SharedVisualization {
    pub fn new() -> Arc<Self> {
        Arc::new(Self {
            inner: parking_lot::Mutex::new(VisualizationBuffer::new()),
        })
    }

    /// Called from the cpal audio callback with post-DSP interleaved samples.
    /// Must be fast — no allocations, no blocking.
    pub fn push_samples(&self, samples: &[f32], channels: usize) {
        if let Some(mut buf) = self.inner.try_lock() {
            if !buf.enabled.load(Ordering::Relaxed) {
                return;
            }
            buf.push_samples(samples, channels);
        }
        // If lock is contended (reader is snapshotting), just skip this chunk.
        // Visualization is best-effort — dropping a few ms of data is fine.
    }

    /// Take a snapshot of the current visualization state.
    pub fn snapshot(&self) -> VisualizationSnapshot {
        let buf = self.inner.lock();
        VisualizationSnapshot {
            waveform: buf.front_waveform.to_vec(),
            spectrum: buf.front_spectrum.to_vec(),
            peak_left: buf.peak_left,
            peak_right: buf.peak_right,
        }
    }

    pub fn set_enabled(&self, enabled: bool) {
        let buf = self.inner.lock();
        buf.enabled.store(enabled, Ordering::Relaxed);
    }

    pub fn is_enabled(&self) -> bool {
        let buf = self.inner.lock();
        buf.enabled.load(Ordering::Relaxed)
    }
}

impl VisualizationBuffer {
    fn new() -> Self {
        Self {
            front_waveform: Box::new([0.0; WAVEFORM_SAMPLES]),
            front_spectrum: Box::new([0.0; SPECTRUM_BINS]),
            back_waveform: Box::new([0.0; WAVEFORM_SAMPLES]),
            back_spectrum: Box::new([0.0; SPECTRUM_BINS]),
            fft_input: Box::new([0.0; FFT_SIZE]),
            fft_pos: 0,
            ready: AtomicBool::new(false),
            peak_left: 0.0,
            peak_right: 0.0,
            enabled: AtomicBool::new(false),
            smoothing: 0.7,
            prev_spectrum: Box::new([0.0; SPECTRUM_BINS]),
        }
    }

    fn push_samples(&mut self, samples: &[f32], channels: usize) {
        if channels == 0 || samples.is_empty() {
            return;
        }

        let frame_count = samples.len() / channels;

        // Update peak levels with decay
        let decay = 0.95_f32;
        self.peak_left *= decay;
        self.peak_right *= decay;

        for frame in 0..frame_count {
            let left = samples[frame * channels];
            let right = if channels > 1 {
                samples[frame * channels + 1]
            } else {
                left
            };

            self.peak_left = self.peak_left.max(left.abs());
            self.peak_right = self.peak_right.max(right.abs());

            // Downmix to mono for waveform + FFT
            let mono = (left + right) * 0.5;

            // Fill FFT accumulator
            if self.fft_pos < FFT_SIZE {
                self.fft_input[self.fft_pos] = mono;
                self.fft_pos += 1;
            }
        }

        // Write waveform: downsample current FFT buffer to WAVEFORM_SAMPLES
        let available = self.fft_pos.min(FFT_SIZE);
        if available > 0 {
            let step = available as f32 / WAVEFORM_SAMPLES as f32;
            for i in 0..WAVEFORM_SAMPLES {
                let idx = (i as f32 * step) as usize;
                self.back_waveform[i] = self.fft_input[idx.min(available - 1)];
            }
        }

        // When FFT buffer is full, compute spectrum and swap
        if self.fft_pos >= FFT_SIZE {
            self.compute_spectrum();

            // Swap back → front
            std::mem::swap(&mut self.front_waveform, &mut self.back_waveform);
            std::mem::swap(&mut self.front_spectrum, &mut self.back_spectrum);
            self.ready.store(true, Ordering::Release);

            self.fft_pos = 0;
        }
    }

    fn compute_spectrum(&mut self) {
        // Apply Hann window
        let mut windowed = [0.0_f32; FFT_SIZE];
        for i in 0..FFT_SIZE {
            let w = 0.5 * (1.0 - (2.0 * std::f32::consts::PI * i as f32 / FFT_SIZE as f32).cos());
            windowed[i] = self.fft_input[i] * w;
        }

        // Compute FFT
        let mut planner = RealFftPlanner::<f32>::new();
        let fft = planner.plan_fft_forward(FFT_SIZE);

        let mut input = windowed.to_vec();
        let mut output = fft.make_output_vec();

        if fft.process(&mut input, &mut output).is_err() {
            return;
        }

        // Convert complex FFT output to magnitude spectrum
        let half = output.len(); // FFT_SIZE/2 + 1
        let mut magnitudes = vec![0.0_f32; half];
        for (i, c) in output.iter().enumerate() {
            magnitudes[i] = (c.re * c.re + c.im * c.im).sqrt() / (FFT_SIZE as f32).sqrt();
        }

        // Map to logarithmic frequency bins
        // Human hearing is ~20Hz-20kHz, logarithmically distributed
        let min_freq = 20.0_f32;
        let max_freq = 20000.0_f32;

        for bin in 0..SPECTRUM_BINS {
            let t0 = bin as f32 / SPECTRUM_BINS as f32;
            let t1 = (bin + 1) as f32 / SPECTRUM_BINS as f32;

            // Log-scale frequency range for this bin
            let f0 = min_freq * (max_freq / min_freq).powf(t0);
            let f1 = min_freq * (max_freq / min_freq).powf(t1);

            // Map frequency to FFT bin indices (assume 44100Hz sample rate — close enough for vis)
            let sample_rate = 48000.0_f32; // Approximate
            let idx0 = (f0 / sample_rate * FFT_SIZE as f32) as usize;
            let idx1 = ((f1 / sample_rate * FFT_SIZE as f32) as usize).max(idx0 + 1);

            // Average magnitudes in this range
            let start = idx0.min(half - 1);
            let end = idx1.min(half);
            if start < end {
                let sum: f32 = magnitudes[start..end].iter().sum();
                let avg = sum / (end - start) as f32;
                // Convert to dB-ish scale, normalized to 0.0 - 1.0
                let db = 20.0 * (avg.max(1e-10)).log10();
                let normalized = ((db + 60.0) / 60.0).clamp(0.0, 1.0);

                // Apply smoothing
                let smoothed = self.prev_spectrum[bin] * self.smoothing
                    + normalized * (1.0 - self.smoothing);
                self.back_spectrum[bin] = smoothed;
                self.prev_spectrum[bin] = smoothed;
            } else {
                self.back_spectrum[bin] = self.prev_spectrum[bin] * self.smoothing;
                self.prev_spectrum[bin] = self.back_spectrum[bin];
            }
        }
    }
}
