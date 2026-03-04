//! Symphonia-based audio decoder.
//!
//! Runs on the decoder thread. Reads audio files, decodes to PCM,
//! and pushes samples into the ring buffer for the audio thread.

use crate::{AudioError, AudioEvent, Command, TrackInfo};
use crossbeam_channel::{Receiver, Sender};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use symphonia::core::audio::SampleBuffer;
use symphonia::core::codecs::{DecoderOptions, CODEC_TYPE_NULL};
use symphonia::core::formats::{FormatOptions, SeekMode, SeekTo};
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;
use symphonia::core::probe::Hint;
use symphonia::core::units::Time;

/// Shared ring buffer between decoder and output threads.
/// Lock-free SPSC: decoder writes, output reads.
pub struct RingBuffer {
    buf: Box<[f32]>,
    capacity: usize,
    write_pos: std::sync::atomic::AtomicUsize,
    read_pos: std::sync::atomic::AtomicUsize,
}

impl RingBuffer {
    pub fn new(capacity: usize) -> Self {
        Self {
            buf: vec![0.0f32; capacity].into_boxed_slice(),
            capacity,
            write_pos: std::sync::atomic::AtomicUsize::new(0),
            read_pos: std::sync::atomic::AtomicUsize::new(0),
        }
    }

    /// Available samples to read.
    pub fn available(&self) -> usize {
        let w = self.write_pos.load(Ordering::Acquire);
        let r = self.read_pos.load(Ordering::Acquire);
        if w >= r { w - r } else { self.capacity - r + w }
    }

    /// Free space for writing.
    pub fn free(&self) -> usize {
        self.capacity - 1 - self.available()
    }

    /// Write samples into the ring buffer. Returns number actually written.
    pub fn write(&self, data: &[f32]) -> usize {
        let free = self.free();
        let to_write = data.len().min(free);
        if to_write == 0 {
            return 0;
        }

        let w = self.write_pos.load(Ordering::Acquire);
        let buf_ptr = self.buf.as_ptr() as *mut f32;

        let first_chunk = (self.capacity - w).min(to_write);
        unsafe {
            std::ptr::copy_nonoverlapping(data.as_ptr(), buf_ptr.add(w), first_chunk);
            if to_write > first_chunk {
                std::ptr::copy_nonoverlapping(
                    data.as_ptr().add(first_chunk),
                    buf_ptr,
                    to_write - first_chunk,
                );
            }
        }

        let new_w = (w + to_write) % self.capacity;
        self.write_pos.store(new_w, Ordering::Release);
        to_write
    }

    /// Read samples from the ring buffer. Returns number actually read.
    pub fn read(&self, out: &mut [f32]) -> usize {
        let avail = self.available();
        let to_read = out.len().min(avail);
        if to_read == 0 {
            return 0;
        }

        let r = self.read_pos.load(Ordering::Acquire);

        let first_chunk = (self.capacity - r).min(to_read);
        unsafe {
            std::ptr::copy_nonoverlapping(self.buf.as_ptr().add(r), out.as_mut_ptr(), first_chunk);
            if to_read > first_chunk {
                std::ptr::copy_nonoverlapping(
                    self.buf.as_ptr(),
                    out.as_mut_ptr().add(first_chunk),
                    to_read - first_chunk,
                );
            }
        }

        let new_r = (r + to_read) % self.capacity;
        self.read_pos.store(new_r, Ordering::Release);
        to_read
    }

    /// Clear the buffer.
    pub fn clear(&self) {
        self.read_pos.store(0, Ordering::Release);
        self.write_pos.store(0, Ordering::Release);
    }
}

// Safety: RingBuffer is designed for single-producer single-consumer use.
// The decoder thread writes, the output thread reads. Atomic positions ensure
// correct ordering without locks.
unsafe impl Send for RingBuffer {}
unsafe impl Sync for RingBuffer {}

/// Probe a file and return track information without decoding.
pub fn probe_track(path: &str) -> Result<TrackInfo, AudioError> {
    let file = std::fs::File::open(path)
        .map_err(|e| AudioError::FileNotFound(format!("{}: {}", path, e)))?;

    let mss = MediaSourceStream::new(Box::new(file), Default::default());
    let mut hint = Hint::new();

    if let Some(ext) = std::path::Path::new(path).extension().and_then(|e| e.to_str()) {
        hint.with_extension(ext);
    }

    let probed = symphonia::default::get_probe()
        .format(&hint, mss, &Default::default(), &Default::default())
        .map_err(|e| AudioError::UnsupportedFormat(format!("{}: {}", path, e)))?;

    let format = probed.format;
    let track = format
        .default_track()
        .ok_or_else(|| AudioError::Decode("No default track found".into()))?;

    let codec_params = &track.codec_params;
    let sample_rate = codec_params.sample_rate.unwrap_or(44100);
    let channels = codec_params.channels.map(|c| c.count() as u16).unwrap_or(2);
    let bit_depth = codec_params.bits_per_sample.map(|b| b as u16);

    let duration_ms = track
        .codec_params
        .n_frames
        .map(|frames| frames * 1000 / sample_rate as u64)
        .unwrap_or(0);

    let codec = format!("{:?}", codec_params.codec);

    Ok(TrackInfo {
        path: path.to_string(),
        duration_ms,
        sample_rate,
        channels,
        bit_depth,
        codec,
    })
}

/// State for the decoder thread.
struct DecoderState {
    cmd_rx: Receiver<Command>,
    event_tx: Sender<AudioEvent>,
    ring: Arc<RingBuffer>,
    playing: Arc<AtomicBool>,
    paused: bool,
    current_track: Option<ActiveTrack>,
    sample_rate: u32,
    channels: u16,
}

struct ActiveTrack {
    reader: Box<dyn symphonia::core::formats::FormatReader>,
    decoder: Box<dyn symphonia::core::codecs::Decoder>,
    track_id: u32,
    info: TrackInfo,
    samples_decoded: u64,
}

/// Run the decoder thread. Blocks until Shutdown command received.
pub fn decoder_thread(
    cmd_rx: Receiver<Command>,
    event_tx: Sender<AudioEvent>,
    ring: Arc<RingBuffer>,
    playing: Arc<AtomicBool>,
) {
    let mut state = DecoderState {
        cmd_rx,
        event_tx,
        ring,
        playing,
        paused: false,
        current_track: None,
        sample_rate: 0,
        channels: 0,
    };

    loop {
        // Check for commands (non-blocking if we're actively decoding)
        if state.current_track.is_some() && !state.paused {
            // Decode a chunk, then check commands
            match state.cmd_rx.try_recv() {
                Ok(cmd) => {
                    if handle_command(&mut state, cmd) {
                        return;
                    }
                }
                Err(crossbeam_channel::TryRecvError::Empty) => {}
                Err(crossbeam_channel::TryRecvError::Disconnected) => return,
            }

            // Decode next packet if ring buffer has space
            if state.ring.free() > 8192 {
                decode_next_packet(&mut state);
            } else {
                // Ring buffer full, wait briefly
                std::thread::sleep(std::time::Duration::from_millis(5));
            }
        } else {
            // Not playing or paused — block on command
            match state.cmd_rx.recv() {
                Ok(cmd) => {
                    if handle_command(&mut state, cmd) {
                        return;
                    }
                }
                Err(_) => return,
            }
        }
    }
}

/// Returns true if the thread should exit.
fn handle_command(state: &mut DecoderState, cmd: Command) -> bool {
    match cmd {
        Command::Load(path) => {
            load_track(state, &path);
        }
        Command::Play => {
            state.paused = false;
            state.playing.store(true, Ordering::Release);
            let _ = state
                .event_tx
                .send(AudioEvent::StateChanged(crate::state::PlayerState::Playing));
        }
        Command::Pause => {
            state.paused = true;
            state.playing.store(false, Ordering::Release);
            let _ = state
                .event_tx
                .send(AudioEvent::StateChanged(crate::state::PlayerState::Paused));
        }
        Command::Stop => {
            state.current_track = None;
            state.paused = false;
            state.playing.store(false, Ordering::Release);
            state.ring.clear();
            let _ = state
                .event_tx
                .send(AudioEvent::StateChanged(crate::state::PlayerState::Stopped));
        }
        Command::Seek(ms) => {
            seek_to(state, ms);
        }
        Command::SetVolume(_) | Command::SetEq(_) | Command::SetCrossfade(_) | Command::SetGapless(_) => {
            // These are handled by the pipeline/engine, not the decoder
        }
        Command::Shutdown => return true,
    }
    false
}

fn load_track(state: &mut DecoderState, path: &str) {
    // Stop current playback
    state.current_track = None;
    state.ring.clear();
    state.playing.store(false, Ordering::Release);

    let _ = state
        .event_tx
        .send(AudioEvent::StateChanged(crate::state::PlayerState::Loading));

    let file = match std::fs::File::open(path) {
        Ok(f) => f,
        Err(e) => {
            let _ = state
                .event_tx
                .send(AudioEvent::Error(format!("File not found: {}: {}", path, e)));
            return;
        }
    };

    let mss = MediaSourceStream::new(Box::new(file), Default::default());
    let mut hint = Hint::new();
    if let Some(ext) = std::path::Path::new(path).extension().and_then(|e| e.to_str()) {
        hint.with_extension(ext);
    }

    let probed = match symphonia::default::get_probe().format(
        &hint,
        mss,
        &FormatOptions::default(),
        &MetadataOptions::default(),
    ) {
        Ok(p) => p,
        Err(e) => {
            let _ = state.event_tx.send(AudioEvent::Error(format!(
                "Unsupported format: {}: {}",
                path, e
            )));
            return;
        }
    };

    let reader = probed.format;
    let track = match reader.default_track() {
        Some(t) => t.clone(),
        None => {
            let _ = state
                .event_tx
                .send(AudioEvent::Error("No audio track found".into()));
            return;
        }
    };

    if track.codec_params.codec == CODEC_TYPE_NULL {
        let _ = state
            .event_tx
            .send(AudioEvent::Error("Null codec".into()));
        return;
    }

    let decoder = match symphonia::default::get_codecs().make(&track.codec_params, &DecoderOptions::default()) {
        Ok(d) => d,
        Err(e) => {
            let _ = state.event_tx.send(AudioEvent::Error(format!(
                "Codec error: {}",
                e
            )));
            return;
        }
    };

    let sample_rate = track.codec_params.sample_rate.unwrap_or(44100);
    let channels = track.codec_params.channels.map(|c| c.count() as u16).unwrap_or(2);
    let bit_depth = track.codec_params.bits_per_sample.map(|b| b as u16);
    let duration_ms = track
        .codec_params
        .n_frames
        .map(|frames| frames * 1000 / sample_rate as u64)
        .unwrap_or(0);
    let codec_name = format!("{:?}", track.codec_params.codec);

    let info = TrackInfo {
        path: path.to_string(),
        duration_ms,
        sample_rate,
        channels,
        bit_depth,
        codec: codec_name,
    };

    state.sample_rate = sample_rate;
    state.channels = channels;

    let _ = state.event_tx.send(AudioEvent::TrackLoaded(info.clone()));

    state.current_track = Some(ActiveTrack {
        reader,
        decoder,
        track_id: track.id,
        info,
        samples_decoded: 0,
    });

    // Auto-play on load
    state.paused = false;
    state.playing.store(true, Ordering::Release);
    let _ = state
        .event_tx
        .send(AudioEvent::StateChanged(crate::state::PlayerState::Playing));
}

fn decode_next_packet(state: &mut DecoderState) {
    let active = match state.current_track.as_mut() {
        Some(a) => a,
        None => return,
    };

    let packet = match active.reader.next_packet() {
        Ok(p) => p,
        Err(symphonia::core::errors::Error::IoError(ref e))
            if e.kind() == std::io::ErrorKind::UnexpectedEof =>
        {
            // End of stream
            let _ = state.event_tx.send(AudioEvent::TrackFinished);
            state.playing.store(false, Ordering::Release);
            let _ = state
                .event_tx
                .send(AudioEvent::StateChanged(crate::state::PlayerState::Stopped));
            state.current_track = None;
            return;
        }
        Err(e) => {
            let _ = state
                .event_tx
                .send(AudioEvent::Error(format!("Read error: {}", e)));
            return;
        }
    };

    // Skip packets for other tracks
    if packet.track_id() != active.track_id {
        return;
    }

    let decoded = match active.decoder.decode(&packet) {
        Ok(d) => d,
        Err(symphonia::core::errors::Error::DecodeError(e)) => {
            log::warn!("Decode error (skipping packet): {}", e);
            return;
        }
        Err(e) => {
            let _ = state
                .event_tx
                .send(AudioEvent::Error(format!("Decode error: {}", e)));
            return;
        }
    };

    let spec = *decoded.spec();
    let num_frames = decoded.frames();
    // Convert to interleaved f32
    let mut sample_buf = SampleBuffer::<f32>::new(num_frames as u64, spec);
    sample_buf.copy_interleaved_ref(decoded);
    let samples = sample_buf.samples();

    // Write to ring buffer
    let mut offset = 0;
    while offset < samples.len() {
        let written = state.ring.write(&samples[offset..]);
        if written == 0 {
            // Ring buffer full, yield
            std::thread::sleep(std::time::Duration::from_millis(1));
        }
        offset += written;
    }

    active.samples_decoded += num_frames as u64;

    // Send position update (every ~100ms worth of samples)
    let samples_per_100ms = (state.sample_rate as u64) / 10;
    if active.samples_decoded % samples_per_100ms < num_frames as u64 {
        let position_ms = active.samples_decoded * 1000 / state.sample_rate as u64;
        let _ = state.event_tx.send(AudioEvent::Position(position_ms));
    }
}

fn seek_to(state: &mut DecoderState, ms: u64) {
    let active = match state.current_track.as_mut() {
        Some(a) => a,
        None => return,
    };

    let time = Time::new(ms / 1000, (ms % 1000) as f64 / 1000.0);
    let seek_to = SeekTo::Time {
        time,
        track_id: Some(active.track_id),
    };

    match active.reader.seek(SeekMode::Accurate, seek_to) {
        Ok(seeked) => {
            active.decoder.reset();
            state.ring.clear();
            let position_ms = seeked.actual_ts * 1000
                / active.info.sample_rate as u64;
            active.samples_decoded = seeked.actual_ts;
            let _ = state.event_tx.send(AudioEvent::Position(position_ms));
        }
        Err(e) => {
            let _ = state
                .event_tx
                .send(AudioEvent::Error(format!("Seek error: {}", e)));
        }
    }
}
