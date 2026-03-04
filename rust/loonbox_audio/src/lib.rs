//! LoonBox Audio Engine
//!
//! Three-thread architecture:
//! - Control thread: receives commands from Dart via FFI
//! - Decoder thread: reads/decodes audio via Symphonia, pushes PCM to ring buffer
//! - Audio thread: cpal callback, reads from ring buffer, never allocates

pub mod crossfade;
pub mod decoder;
pub mod equalizer;
pub mod gapless;
pub mod output;
pub mod pipeline;
pub mod resampler;
pub mod state;

use crossbeam_channel::{Receiver, Sender};
use decoder::RingBuffer;
use parking_lot::Mutex;
use pipeline::DspPipeline;
use state::PlayerState;
use std::sync::atomic::AtomicBool;
use std::sync::Arc;
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
    Seek(u64),      // position in ms
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

// Ring buffer size: ~2 seconds of stereo 48kHz audio
const RING_BUFFER_SAMPLES: usize = 48000 * 2 * 2;

/// The audio engine handle. Created once, lives for app lifetime.
///
/// Note: AudioEngine is Send+Sync. The cpal Stream (which is !Send) is
/// kept alive on the thread that creates the engine via `init_audio_system()`.
pub struct AudioEngine {
    cmd_tx: Sender<Command>,
    event_rx: Receiver<AudioEvent>,
    pipeline: Arc<Mutex<DspPipeline>>,
}

// AudioEngine only contains channels and an Arc<Mutex<DspPipeline>>, all Send+Sync.
unsafe impl Send for AudioEngine {}
unsafe impl Sync for AudioEngine {}

/// Initialize the full audio system. Returns the engine handle and the output handle.
/// The OutputHandle must be kept alive on the calling thread (it contains a cpal Stream
/// which is !Send).
pub fn init_audio_system() -> Result<(AudioEngine, output::OutputHandle), AudioError> {
    let (cmd_tx, cmd_rx) = crossbeam_channel::unbounded();
    let (event_tx, event_rx) = crossbeam_channel::unbounded();

    // Shared state
    let ring = Arc::new(RingBuffer::new(RING_BUFFER_SAMPLES));
    let playing = Arc::new(AtomicBool::new(false));
    let pipeline = Arc::new(Mutex::new(DspPipeline::new()));

    // Initialize audio output (creates cpal stream)
    let output_handle = output::init_output(ring.clone(), pipeline.clone(), playing.clone())?;

    // Update DSP pipeline sample rate to match output device
    {
        let mut dsp = pipeline.lock();
        dsp.equalizer = equalizer::Equalizer::new(output_handle.sample_rate as f32);
    }

    // Start the output stream (it will output silence until playing=true)
    output_handle.start()?;

    // Spawn decoder thread
    let ring_dec = ring.clone();
    let playing_dec = playing.clone();
    std::thread::Builder::new()
        .name("loonbox-decoder".into())
        .spawn(move || {
            decoder::decoder_thread(cmd_rx, event_tx, ring_dec, playing_dec);
        })
        .map_err(|e| AudioError::Pipeline(format!("Failed to spawn decoder thread: {}", e)))?;

    let engine = AudioEngine {
        cmd_tx,
        event_rx,
        pipeline,
    };

    Ok((engine, output_handle))
}

impl AudioEngine {
    /// Send a command to the decoder thread.
    pub fn send_command(&self, cmd: Command) -> Result<(), AudioError> {
        // Handle volume and EQ locally (they affect the DSP pipeline, not the decoder)
        match &cmd {
            Command::SetVolume(vol) => {
                self.pipeline.lock().set_volume(*vol);
                return Ok(());
            }
            Command::SetEq(bands) => {
                self.pipeline.lock().equalizer.set_bands(bands);
                return Ok(());
            }
            _ => {}
        }

        self.cmd_tx
            .send(cmd)
            .map_err(|e| AudioError::Pipeline(e.to_string()))
    }

    /// Try to receive an event from the decoder/output threads.
    pub fn try_recv_event(&self) -> Option<AudioEvent> {
        self.event_rx.try_recv().ok()
    }
}

impl Drop for AudioEngine {
    fn drop(&mut self) {
        let _ = self.cmd_tx.send(Command::Shutdown);
    }
}
