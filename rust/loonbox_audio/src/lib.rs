//! LoonBox Audio Engine
//!
//! Three-thread architecture:
//! - Control thread: receives commands from Dart via FFI
//! - Decoder thread: reads/decodes audio via Symphonia, pushes PCM to ring buffer
//! - Audio thread: cpal callback, reads from ring buffer, never allocates

pub mod decoder;
pub mod equalizer;
pub mod gapless;
pub mod crossfade;
pub mod output;
pub mod pipeline;
pub mod resampler;
pub mod state;

use crossbeam_channel::{Receiver, Sender};
use state::PlayerState;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AudioError {
    #[error("Decode error: {0}")]
    Decode(String),
    #[error("Output error: {0}")]
    Output(String),
    #[error("File not found: {0}")]
    FileNotFound(String),
    #[error("Unsupported format: {0}")]
    UnsupportedFormat(String),
    #[error("Seek error: {0}")]
    Seek(String),
    #[error("Pipeline error: {0}")]
    Pipeline(String),
}

/// Commands sent from the control thread to the decoder thread.
#[derive(Debug)]
pub enum Command {
    Load(String),
    Play,
    Pause,
    Stop,
    Seek(u64),     // position in ms
    SetVolume(f32), // 0.0 - 1.0
    SetEq([f32; 10]),
    SetGapless(bool),
    SetCrossfade(u32), // duration in ms
    Shutdown,
}

/// Events sent from the decoder/audio threads back to the control thread.
#[derive(Debug, Clone)]
pub enum AudioEvent {
    Position(u64),
    StateChanged(PlayerState),
    TrackLoaded(TrackInfo),
    TrackFinished,
    Error(String),
    BufferProgress(f32),
}

/// Information about a decoded track.
#[derive(Debug, Clone)]
pub struct TrackInfo {
    pub path: String,
    pub duration_ms: u64,
    pub sample_rate: u32,
    pub channels: u16,
    pub bit_depth: Option<u16>,
    pub codec: String,
}

/// The audio engine handle. Created once, lives for app lifetime.
pub struct AudioEngine {
    cmd_tx: Sender<Command>,
    event_rx: Receiver<AudioEvent>,
}

impl AudioEngine {
    /// Create a new audio engine. Spawns decoder and audio threads.
    pub fn new() -> Result<Self, AudioError> {
        let (cmd_tx, _cmd_rx) = crossbeam_channel::unbounded();
        let (_event_tx, event_rx) = crossbeam_channel::unbounded();

        // TODO: Spawn decoder thread
        // TODO: Spawn audio output thread (cpal)

        Ok(Self { cmd_tx, event_rx })
    }

    pub fn send_command(&self, cmd: Command) -> Result<(), AudioError> {
        self.cmd_tx
            .send(cmd)
            .map_err(|e| AudioError::Pipeline(e.to_string()))
    }

    pub fn try_recv_event(&self) -> Option<AudioEvent> {
        self.event_rx.try_recv().ok()
    }
}

impl Drop for AudioEngine {
    fn drop(&mut self) {
        let _ = self.cmd_tx.send(Command::Shutdown);
    }
}
