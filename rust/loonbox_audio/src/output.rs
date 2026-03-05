//! Audio output via cpal.
//!
//! Runs on a real-time audio callback thread.
//! RULES: Never allocate, never lock a blocking mutex, never do I/O.
//! Read from lock-free ring buffer only.

use crate::decoder::RingBuffer;
use crate::pipeline::DspPipeline;
use crate::visualizer::SharedVisualization;
use crate::AudioError;
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::Stream;
use parking_lot::Mutex;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

/// Handle to the audio output stream.
pub struct OutputHandle {
    stream: Stream,
    pub sample_rate: u32,
    pub channels: u16,
}

impl OutputHandle {
    pub fn start(&self) -> Result<(), AudioError> {
        self.stream
            .play()
            .map_err(|e| AudioError::Output(format!("Failed to start stream: {}", e)))
    }

    pub fn stop(&self) -> Result<(), AudioError> {
        self.stream
            .pause()
            .map_err(|e| AudioError::Output(format!("Failed to pause stream: {}", e)))
    }
}

/// Initialize the default audio output device and create a stream.
///
/// The stream callback reads from the ring buffer and applies DSP processing.
/// The `playing` flag controls whether samples are read or silence is output.
pub fn init_output(
    ring: Arc<RingBuffer>,
    pipeline: Arc<Mutex<DspPipeline>>,
    playing: Arc<AtomicBool>,
    viz: Arc<SharedVisualization>,
) -> Result<OutputHandle, AudioError> {
    let host = cpal::default_host();

    let device = host
        .default_output_device()
        .ok_or_else(|| AudioError::Output("No output device found".into()))?;

    let supported_config = device
        .default_output_config()
        .map_err(|e| AudioError::Output(format!("No output config: {}", e)))?;

    let sample_rate = supported_config.sample_rate().0;
    let channels = supported_config.channels();

    let config = cpal::StreamConfig {
        channels,
        sample_rate: cpal::SampleRate(sample_rate),
        buffer_size: cpal::BufferSize::Default,
    };

    let ring_ref = ring.clone();
    let playing_ref = playing.clone();
    let pipeline_ref = pipeline.clone();
    let viz_ref = viz.clone();
    let ch = channels as usize;

    let stream = device
        .build_output_stream(
            &config,
            move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                if !playing_ref.load(Ordering::Acquire) {
                    // Output silence when not playing
                    data.fill(0.0);
                    return;
                }

                let read = ring_ref.read(data);
                if read < data.len() {
                    // Buffer underrun — fill remaining with silence
                    data[read..].fill(0.0);
                }

                // Apply DSP pipeline (EQ, volume, limiter)
                if let Some(mut dsp) = pipeline_ref.try_lock() {
                    dsp.process(&mut data[..read], ch);
                }

                // Feed post-DSP samples to visualization buffer
                viz_ref.push_samples(&data[..read], ch);
            },
            |err| {
                log::error!("Audio output error: {}", err);
            },
            None, // No timeout
        )
        .map_err(|e| AudioError::Output(format!("Failed to build stream: {}", e)))?;

    Ok(OutputHandle {
        stream,
        sample_rate,
        channels,
    })
}
