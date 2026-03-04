//! Sample rate conversion via rubato.
//!
//! Converts decoded audio to the output device's native sample rate.
//! Uses high-quality sinc interpolation for audiophile-grade resampling.

use crate::AudioError;

/// Resampler wrapper around rubato.
pub struct Resampler {
    input_rate: u32,
    output_rate: u32,
}

impl Resampler {
    pub fn new(input_rate: u32, output_rate: u32) -> Self {
        Self {
            input_rate,
            output_rate,
        }
    }

    /// Check if resampling is needed.
    pub fn needs_resampling(&self) -> bool {
        self.input_rate != self.output_rate
    }

    /// Process a buffer of samples. Returns resampled output.
    ///
    /// Full implementation will use rubato::SincFixedIn for high-quality resampling.
    pub fn process(&mut self, _input: &[f32], _channels: usize) -> Result<Vec<f32>, AudioError> {
        // TODO: Implement rubato-based resampling
        // For now, passthrough when rates match
        Err(AudioError::Pipeline("Resampler not yet implemented".into()))
    }

    pub fn set_rates(&mut self, input: u32, output: u32) {
        self.input_rate = input;
        self.output_rate = output;
    }
}
