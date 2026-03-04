//! Audio output via cpal.
//!
//! Runs on a real-time audio callback thread.
//! RULES: Never allocate, never lock a blocking mutex, never do I/O.
//! Read from lock-free ring buffer only.

use crate::AudioError;

/// Initialize the default audio output device.
///
/// Full implementation will:
/// 1. Get default output device via cpal
/// 2. Get preferred output config (sample rate, channels)
/// 3. Build output stream with callback that reads from ring buffer
/// 4. Return handle to start/stop the stream
pub fn init_output() -> Result<OutputHandle, AudioError> {
    // TODO: Initialize cpal output
    Ok(OutputHandle { _private: () })
}

pub struct OutputHandle {
    _private: (),
}

impl OutputHandle {
    pub fn start(&self) -> Result<(), AudioError> {
        // TODO: Start the cpal stream
        Ok(())
    }

    pub fn stop(&self) -> Result<(), AudioError> {
        // TODO: Pause/stop the cpal stream
        Ok(())
    }
}
