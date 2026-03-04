//! Sample rate conversion via rubato.
//!
//! Converts decoded audio to the output device's native sample rate.
//! Uses high-quality sinc interpolation for audiophile-grade resampling.

use crate::AudioError;
use rubato::{FftFixedIn, Resampler as RubatoResampler};

/// Resampler wrapper around rubato.
pub struct Resampler {
    inner: Option<FftFixedIn<f32>>,
    input_rate: u32,
    output_rate: u32,
    channels: usize,
    input_buf: Vec<Vec<f32>>,
}

impl Resampler {
    pub fn new(input_rate: u32, output_rate: u32, channels: usize) -> Result<Self, AudioError> {
        let inner = if input_rate != output_rate {
            // chunk_size=1024 is a good default for real-time use
            Some(
                FftFixedIn::new(input_rate as usize, output_rate as usize, 1024, 2, channels)
                    .map_err(|e| AudioError::Pipeline(format!("Resampler init: {}", e)))?,
            )
        } else {
            None
        };

        Ok(Self {
            inner,
            input_rate,
            output_rate,
            channels,
            input_buf: vec![Vec::new(); channels],
        })
    }

    /// Check if resampling is needed.
    pub fn needs_resampling(&self) -> bool {
        self.input_rate != self.output_rate
    }

    /// Process interleaved samples. Returns resampled interleaved output.
    pub fn process(&mut self, input: &[f32]) -> Result<Vec<f32>, AudioError> {
        let resampler = match self.inner.as_mut() {
            Some(r) => r,
            None => return Ok(input.to_vec()), // No resampling needed
        };

        let frames = input.len() / self.channels;

        // Deinterleave into per-channel buffers
        for ch_buf in self.input_buf.iter_mut() {
            ch_buf.clear();
            ch_buf.reserve(frames);
        }
        for (i, sample) in input.iter().enumerate() {
            self.input_buf[i % self.channels].push(*sample);
        }

        // Resample
        let resampled = resampler
            .process(&self.input_buf, None)
            .map_err(|e| AudioError::Pipeline(format!("Resample error: {}", e)))?;

        // Re-interleave
        let out_frames = resampled.get(0).map(|c| c.len()).unwrap_or(0);
        let mut interleaved = Vec::with_capacity(out_frames * self.channels);
        for frame in 0..out_frames {
            for ch in 0..self.channels {
                interleaved.push(resampled[ch][frame]);
            }
        }

        Ok(interleaved)
    }

    pub fn set_rates(&mut self, input: u32, output: u32) -> Result<(), AudioError> {
        if input != self.input_rate || output != self.output_rate {
            self.input_rate = input;
            self.output_rate = output;
            if input != output {
                self.inner = Some(
                    FftFixedIn::new(input as usize, output as usize, 1024, 2, self.channels)
                        .map_err(|e| AudioError::Pipeline(format!("Resampler reinit: {}", e)))?,
                );
            } else {
                self.inner = None;
            }
        }
        Ok(())
    }
}
