//! DSP processing pipeline.
//!
//! Chain: Decoder -> Resampler -> EQ -> ReplayGain -> Volume -> Crossfade -> Limiter -> Output
//!
//! All processing is done in f32 sample format.

use crate::equalizer::Equalizer;

/// The DSP pipeline processes decoded audio samples before output.
pub struct DspPipeline {
    pub equalizer: Equalizer,
    pub volume: f32,
    pub replay_gain_db: f32,
    pub replay_gain_enabled: bool,
}

impl DspPipeline {
    pub fn new() -> Self {
        Self {
            equalizer: Equalizer::new(44100.0),
            volume: 1.0,
            replay_gain_db: 0.0,
            replay_gain_enabled: false,
        }
    }

    /// Process a buffer of interleaved stereo f32 samples in-place.
    pub fn process(&mut self, samples: &mut [f32], channels: usize) {
        // EQ
        self.equalizer.process(samples, channels);

        // ReplayGain
        if self.replay_gain_enabled && self.replay_gain_db != 0.0 {
            let gain = 10.0_f32.powf(self.replay_gain_db / 20.0);
            for s in samples.iter_mut() {
                *s *= gain;
            }
        }

        // Volume
        if self.volume != 1.0 {
            for s in samples.iter_mut() {
                *s *= self.volume;
            }
        }

        // Soft limiter to prevent clipping
        for s in samples.iter_mut() {
            *s = soft_clip(*s);
        }
    }

    pub fn set_volume(&mut self, vol: f32) {
        self.volume = vol.clamp(0.0, 1.0);
    }
}

/// Soft clipping function to prevent harsh digital clipping.
#[inline]
fn soft_clip(x: f32) -> f32 {
    if x.abs() <= 0.9 {
        x
    } else {
        x.signum() * (0.9 + (1.0 - 0.9) * ((x.abs() - 0.9) / (1.0 - 0.9)).tanh())
    }
}
