//! Sample rate conversion via rubato.
//!
//! Converts decoded audio to the output device's native sample rate.
//! Buffers input to feed rubato in fixed-size chunks.

use crate::AudioError;
use rubato::{FftFixedIn, Resampler as RubatoResampler};

const CHUNK_SIZE: usize = 1024;

/// Resampler wrapper around rubato with internal buffering.
///
/// Accepts variable-length interleaved input, buffers it, and processes
/// in fixed 1024-frame chunks as required by FftFixedIn.
pub struct Resampler {
    inner: FftFixedIn<f32>,
    channels: usize,
    /// Per-channel input accumulation buffers
    pending: Vec<Vec<f32>>,
    /// Interleaved output accumulation
    output_buf: Vec<f32>,
}

impl Resampler {
    pub fn new(input_rate: u32, output_rate: u32, channels: usize) -> Result<Self, AudioError> {
        let inner =
            FftFixedIn::new(input_rate as usize, output_rate as usize, CHUNK_SIZE, 2, channels)
                .map_err(|e| AudioError::Pipeline(format!("Resampler init: {}", e)))?;

        Ok(Self {
            inner,
            channels,
            pending: vec![Vec::with_capacity(CHUNK_SIZE * 2); channels],
            output_buf: Vec::with_capacity(CHUNK_SIZE * 2 * channels),
        })
    }

    /// Process interleaved samples. Returns resampled interleaved output.
    ///
    /// Input can be any length. Samples are buffered internally and processed
    /// in CHUNK_SIZE-frame batches. Any leftover frames are kept for the next call.
    pub fn process(&mut self, input: &[f32]) -> Result<Vec<f32>, AudioError> {
        // Deinterleave input into per-channel pending buffers
        for (i, &sample) in input.iter().enumerate() {
            self.pending[i % self.channels].push(sample);
        }

        self.output_buf.clear();

        // Process complete chunks
        while self.pending[0].len() >= CHUNK_SIZE {
            // Extract exactly CHUNK_SIZE frames per channel
            let chunk: Vec<Vec<f32>> = self
                .pending
                .iter_mut()
                .map(|ch| ch.drain(..CHUNK_SIZE).collect())
                .collect();

            let resampled = self
                .inner
                .process(&chunk, None)
                .map_err(|e| AudioError::Pipeline(format!("Resample error: {}", e)))?;

            // Re-interleave into output
            let out_frames = resampled.first().map(|c| c.len()).unwrap_or(0);
            for frame in 0..out_frames {
                for ch in 0..self.channels {
                    self.output_buf.push(resampled[ch][frame]);
                }
            }
        }

        Ok(std::mem::take(&mut self.output_buf))
    }

    /// Flush any remaining buffered samples (pad with silence to fill a chunk).
    /// Call this at end-of-track to avoid losing the tail.
    pub fn flush(&mut self) -> Result<Vec<f32>, AudioError> {
        let remaining = self.pending[0].len();
        if remaining == 0 {
            return Ok(Vec::new());
        }

        // Pad each channel to CHUNK_SIZE with silence
        for ch in self.pending.iter_mut() {
            ch.resize(CHUNK_SIZE, 0.0);
        }

        let chunk: Vec<Vec<f32>> = self
            .pending
            .iter_mut()
            .map(|ch| ch.drain(..).collect())
            .collect();

        let resampled = self
            .inner
            .process(&chunk, None)
            .map_err(|e| AudioError::Pipeline(format!("Resample flush error: {}", e)))?;

        // Only take the proportion of output that corresponds to real input
        let ratio = self.inner.output_frames_max() as f64 / CHUNK_SIZE as f64;
        let real_out_frames = (remaining as f64 * ratio).ceil() as usize;
        let out_frames = resampled
            .first()
            .map(|c| c.len().min(real_out_frames))
            .unwrap_or(0);

        let mut output = Vec::with_capacity(out_frames * self.channels);
        for frame in 0..out_frames {
            for ch in 0..self.channels {
                output.push(resampled[ch][frame]);
            }
        }

        Ok(output)
    }

    /// Clear internal buffers (call on seek or track change).
    pub fn reset(&mut self) {
        for ch in self.pending.iter_mut() {
            ch.clear();
        }
        self.inner.reset();
    }
}
