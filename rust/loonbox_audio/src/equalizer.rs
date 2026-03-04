//! 10-band parametric equalizer using cascaded biquad filters.
//!
//! Bands: 32Hz, 64Hz, 125Hz, 250Hz, 500Hz, 1kHz, 2kHz, 4kHz, 8kHz, 16kHz
//! Gain range: -12dB to +12dB (stored as -1.0 to 1.0, scaled at application)
//! Q factor: 1.414 (constant for each band)

const BAND_FREQUENCIES: [f32; 10] = [
    32.0, 64.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0,
];
const Q: f32 = 1.414;
const MAX_CHANNELS: usize = 8;

/// Biquad filter coefficients.
#[derive(Clone, Copy)]
struct BiquadCoeffs {
    b0: f32,
    b1: f32,
    b2: f32,
    a1: f32,
    a2: f32,
}

impl Default for BiquadCoeffs {
    fn default() -> Self {
        Self { b0: 1.0, b1: 0.0, b2: 0.0, a1: 0.0, a2: 0.0 }
    }
}

/// Per-channel biquad state.
#[derive(Clone, Copy, Default)]
struct BiquadState {
    x1: f32,
    x2: f32,
    y1: f32,
    y2: f32,
}

/// A single EQ band with biquad filter.
struct Band {
    frequency: f32,
    gain_db: f32,
    coeffs: BiquadCoeffs,
    states: [BiquadState; MAX_CHANNELS],
}

/// 10-band equalizer.
pub struct Equalizer {
    bands: [Band; 10],
    sample_rate: f32,
    enabled: bool,
}

impl Equalizer {
    pub fn new(sample_rate: f32) -> Self {
        let bands = std::array::from_fn(|i| {
            Band {
                frequency: BAND_FREQUENCIES[i],
                gain_db: 0.0,
                coeffs: BiquadCoeffs::default(),
                states: [BiquadState::default(); MAX_CHANNELS],
            }
        });

        Self {
            bands,
            sample_rate,
            enabled: false,
        }
    }

    /// Set gains for all 10 bands. Values in -1.0..1.0 range (mapped to -12..+12 dB).
    pub fn set_bands(&mut self, gains: &[f32; 10]) {
        for (i, &gain) in gains.iter().enumerate() {
            let db = gain * 12.0; // map -1..1 to -12..12 dB
            self.bands[i].gain_db = db;
            self.bands[i].coeffs = compute_peak_eq(
                self.sample_rate,
                self.bands[i].frequency,
                Q,
                db,
            );
        }
        self.enabled = gains.iter().any(|&g| g != 0.0);
    }

    /// Process interleaved audio samples in-place.
    pub fn process(&mut self, samples: &mut [f32], channels: usize) {
        if !self.enabled || channels == 0 {
            return;
        }

        let frame_count = samples.len() / channels;

        for band in &mut self.bands {
            if band.gain_db == 0.0 {
                continue;
            }
            let c = &band.coeffs;

            for frame in 0..frame_count {
                for ch in 0..channels.min(MAX_CHANNELS) {
                    let idx = frame * channels + ch;
                    let x0 = samples[idx];
                    let st = &mut band.states[ch];

                    let y0 = c.b0 * x0 + c.b1 * st.x1 + c.b2 * st.x2
                        - c.a1 * st.y1 - c.a2 * st.y2;

                    st.x2 = st.x1;
                    st.x1 = x0;
                    st.y2 = st.y1;
                    st.y1 = y0;

                    samples[idx] = y0;
                }
            }
        }
    }

    pub fn set_sample_rate(&mut self, rate: f32) {
        self.sample_rate = rate;
        // Recompute all coefficients
        for band in &mut self.bands {
            band.coeffs = compute_peak_eq(rate, band.frequency, Q, band.gain_db);
            band.states = [BiquadState::default(); MAX_CHANNELS];
        }
    }
}

/// Compute biquad coefficients for a peaking EQ filter.
fn compute_peak_eq(sample_rate: f32, freq: f32, q: f32, gain_db: f32) -> BiquadCoeffs {
    if gain_db.abs() < 0.001 {
        return BiquadCoeffs::default();
    }

    let a = 10.0_f32.powf(gain_db / 40.0);
    let w0 = 2.0 * std::f32::consts::PI * freq / sample_rate;
    let sin_w0 = w0.sin();
    let cos_w0 = w0.cos();
    let alpha = sin_w0 / (2.0 * q);

    let b0 = 1.0 + alpha * a;
    let b1 = -2.0 * cos_w0;
    let b2 = 1.0 - alpha * a;
    let a0 = 1.0 + alpha / a;
    let a1 = -2.0 * cos_w0;
    let a2 = 1.0 - alpha / a;

    BiquadCoeffs {
        b0: b0 / a0,
        b1: b1 / a0,
        b2: b2 / a0,
        a1: a1 / a0,
        a2: a2 / a0,
    }
}
