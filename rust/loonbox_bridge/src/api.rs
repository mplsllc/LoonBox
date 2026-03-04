//! Public API surface for flutter_rust_bridge.
//!
//! All functions here are callable from Dart. flutter_rust_bridge v2
//! generates typed async Dart wrappers for each function.

use flutter_rust_bridge::frb;
use once_cell::sync::Lazy;
use parking_lot::Mutex;

// ─── Types ───────────────────────────────────────────────────────────

#[frb]
#[derive(Debug, Clone)]
pub enum PlayerState {
    Stopped,
    Loading,
    Playing,
    Paused,
    Error(String),
}

#[frb]
#[derive(Debug, Clone)]
pub enum RepeatMode {
    Off,
    One,
    All,
}

#[frb]
#[derive(Debug, Clone)]
pub enum PlayerEvent {
    Position(u64),
    StateChanged(PlayerState),
    TrackChanged(TrackInfo),
    Error(String),
    BufferProgress(f32),
}

#[frb]
#[derive(Debug, Clone)]
pub struct TrackInfo {
    pub path: String,
    pub duration_ms: u64,
    pub sample_rate: u32,
    pub channels: u16,
    pub bit_depth: Option<u16>,
    pub codec: String,
}

#[frb]
#[derive(Debug, Clone)]
pub struct TrackMetadata {
    pub path: String,
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album_artist: Option<String>,
    pub album: Option<String>,
    pub track_number: Option<u32>,
    pub disc_number: Option<u32>,
    pub year: Option<u32>,
    pub genre: Option<String>,
    pub duration_ms: Option<u64>,
    pub has_album_art: bool,
    pub file_size: u64,
    pub sample_rate: Option<u32>,
    pub bit_depth: Option<u16>,
    pub channels: Option<u16>,
    pub codec: Option<String>,
    pub musicbrainz_track_id: Option<String>,
    pub musicbrainz_artist_id: Option<String>,
    pub replay_gain_track: Option<f32>,
    pub replay_gain_album: Option<f32>,
}

#[frb]
#[derive(Debug, Clone)]
pub enum ScanEvent {
    Found(TrackMetadata),
    Progress { scanned: u32, total: u32 },
    Complete { total: u32, duration_ms: u64 },
    Error { path: String, error: String },
}

#[frb]
#[derive(Debug, Clone)]
pub enum FileChangeEvent {
    Added(String),
    Removed(String),
    Modified(String),
    Renamed { old_path: String, new_path: String },
}

#[frb]
#[derive(Debug, Clone)]
pub struct LoudnessInfo {
    pub integrated_lufs: f32,
    pub loudness_range: f32,
    pub true_peak: f32,
}

// ─── Engine Singleton ────────────────────────────────────────────────

/// Global audio engine instance. Initialized on first use.
static ENGINE: Lazy<Mutex<Option<loonbox_audio::AudioEngine>>> = Lazy::new(|| Mutex::new(None));

/// Keeps the cpal output stream alive for the app lifetime.
/// OutputHandle is !Send because cpal::Stream is !Send, but we only create it once
/// during init and never move it between threads — it just needs to stay alive.
struct OutputKeepAlive(Option<loonbox_audio::output::OutputHandle>);
unsafe impl Send for OutputKeepAlive {}
unsafe impl Sync for OutputKeepAlive {}

static OUTPUT_HANDLE: Lazy<Mutex<OutputKeepAlive>> =
    Lazy::new(|| Mutex::new(OutputKeepAlive(None)));

/// Current state and position, updated from engine events.
static CURRENT_STATE: Lazy<Mutex<EngineState>> =
    Lazy::new(|| Mutex::new(EngineState::default()));

#[derive(Default)]
pub struct EngineState {
    pub state: EnginePlayerState,
    pub position_ms: u64,
}

#[derive(Default)]
pub enum EnginePlayerState {
    #[default]
    Stopped,
    Loading,
    Playing,
    Paused,
    Error(String),
}

fn ensure_engine() -> anyhow::Result<()> {
    let mut guard = ENGINE.lock();
    if guard.is_none() {
        let (engine, output_handle) = loonbox_audio::init_audio_system()
            .map_err(|e| anyhow::anyhow!("Engine init failed: {}", e))?;
        *guard = Some(engine);
        // Keep the output handle alive — dropping it would kill the audio stream
        OUTPUT_HANDLE.lock().0 = Some(output_handle);
    }
    Ok(())
}

fn with_engine<F, R>(f: F) -> anyhow::Result<R>
where
    F: FnOnce(&loonbox_audio::AudioEngine) -> anyhow::Result<R>,
{
    ensure_engine()?;
    let guard = ENGINE.lock();
    let engine = guard.as_ref().unwrap();
    // Drain events to keep state current
    drain_events(engine);
    f(engine)
}

fn drain_events(engine: &loonbox_audio::AudioEngine) {
    let mut state = CURRENT_STATE.lock();
    while let Some(event) = engine.try_recv_event() {
        match event {
            loonbox_audio::AudioEvent::Position(ms) => state.position_ms = ms,
            loonbox_audio::AudioEvent::StateChanged(s) => {
                state.state = match s {
                    loonbox_audio::state::PlayerState::Stopped => EnginePlayerState::Stopped,
                    loonbox_audio::state::PlayerState::Loading => EnginePlayerState::Loading,
                    loonbox_audio::state::PlayerState::Playing => EnginePlayerState::Playing,
                    loonbox_audio::state::PlayerState::Paused => EnginePlayerState::Paused,
                    loonbox_audio::state::PlayerState::Error(e) => EnginePlayerState::Error(e),
                };
            }
            loonbox_audio::AudioEvent::TrackLoaded(_) => {}
            loonbox_audio::AudioEvent::TrackFinished => {
                state.state = EnginePlayerState::Stopped;
                state.position_ms = 0;
            }
            loonbox_audio::AudioEvent::Error(_) => {}
            loonbox_audio::AudioEvent::BufferProgress(_) => {}
        }
    }
}

// ─── Playback ────────────────────────────────────────────────────────

/// Load and play a track. Returns track info.
#[frb]
pub fn player_load(path: String) -> anyhow::Result<TrackInfo> {
    // Probe first to get info
    let info = loonbox_audio::decoder::probe_track(&path)
        .map_err(|e| anyhow::anyhow!("{}", e))?;

    // Send load command to engine (this will auto-play)
    with_engine(|engine| {
        engine
            .send_command(loonbox_audio::Command::Load(path))
            .map_err(|e| anyhow::anyhow!("{}", e))
    })?;

    Ok(TrackInfo {
        path: info.path,
        duration_ms: info.duration_ms,
        sample_rate: info.sample_rate,
        channels: info.channels,
        bit_depth: info.bit_depth,
        codec: info.codec,
    })
}

#[frb]
pub fn player_play() -> anyhow::Result<()> {
    with_engine(|engine| {
        engine
            .send_command(loonbox_audio::Command::Play)
            .map_err(|e| anyhow::anyhow!("{}", e))
    })
}

#[frb]
pub fn player_pause() -> anyhow::Result<()> {
    with_engine(|engine| {
        engine
            .send_command(loonbox_audio::Command::Pause)
            .map_err(|e| anyhow::anyhow!("{}", e))
    })
}

#[frb]
pub fn player_stop() -> anyhow::Result<()> {
    with_engine(|engine| {
        engine
            .send_command(loonbox_audio::Command::Stop)
            .map_err(|e| anyhow::anyhow!("{}", e))
    })
}

#[frb]
pub fn player_seek(position_ms: u64) -> anyhow::Result<()> {
    with_engine(|engine| {
        engine
            .send_command(loonbox_audio::Command::Seek(position_ms))
            .map_err(|e| anyhow::anyhow!("{}", e))
    })
}

#[frb]
pub fn player_set_volume(volume: f32) -> anyhow::Result<()> {
    with_engine(|engine| {
        engine
            .send_command(loonbox_audio::Command::SetVolume(volume.clamp(0.0, 1.0)))
            .map_err(|e| anyhow::anyhow!("{}", e))
    })
}

#[frb]
pub fn player_get_position() -> anyhow::Result<u64> {
    with_engine(|_| {
        let state = CURRENT_STATE.lock();
        Ok(state.position_ms)
    })
}

#[frb]
pub fn player_get_state() -> anyhow::Result<PlayerState> {
    with_engine(|_| {
        let state = CURRENT_STATE.lock();
        Ok(match &state.state {
            EnginePlayerState::Stopped => PlayerState::Stopped,
            EnginePlayerState::Loading => PlayerState::Loading,
            EnginePlayerState::Playing => PlayerState::Playing,
            EnginePlayerState::Paused => PlayerState::Paused,
            EnginePlayerState::Error(e) => PlayerState::Error(e.clone()),
        })
    })
}

/// Collect pending events from the engine. Call this periodically from Dart.
#[frb]
pub fn player_poll_events() -> anyhow::Result<Vec<PlayerEvent>> {
    ensure_engine()?;
    let guard = ENGINE.lock();
    let engine = match guard.as_ref() {
        Some(e) => e,
        None => return Ok(vec![]),
    };

    let mut events = Vec::new();
    let mut state = CURRENT_STATE.lock();

    while let Some(event) = engine.try_recv_event() {
        match event {
            loonbox_audio::AudioEvent::Position(ms) => {
                state.position_ms = ms;
                events.push(PlayerEvent::Position(ms));
            }
            loonbox_audio::AudioEvent::StateChanged(s) => {
                let ps = match s {
                    loonbox_audio::state::PlayerState::Stopped => {
                        state.state = EnginePlayerState::Stopped;
                        PlayerState::Stopped
                    }
                    loonbox_audio::state::PlayerState::Loading => {
                        state.state = EnginePlayerState::Loading;
                        PlayerState::Loading
                    }
                    loonbox_audio::state::PlayerState::Playing => {
                        state.state = EnginePlayerState::Playing;
                        PlayerState::Playing
                    }
                    loonbox_audio::state::PlayerState::Paused => {
                        state.state = EnginePlayerState::Paused;
                        PlayerState::Paused
                    }
                    loonbox_audio::state::PlayerState::Error(e) => {
                        state.state = EnginePlayerState::Error(e.clone());
                        PlayerState::Error(e)
                    }
                };
                events.push(PlayerEvent::StateChanged(ps));
            }
            loonbox_audio::AudioEvent::TrackLoaded(info) => {
                events.push(PlayerEvent::TrackChanged(TrackInfo {
                    path: info.path,
                    duration_ms: info.duration_ms,
                    sample_rate: info.sample_rate,
                    channels: info.channels,
                    bit_depth: info.bit_depth,
                    codec: info.codec,
                }));
            }
            loonbox_audio::AudioEvent::TrackFinished => {
                state.state = EnginePlayerState::Stopped;
                state.position_ms = 0;
                events.push(PlayerEvent::StateChanged(PlayerState::Stopped));
            }
            loonbox_audio::AudioEvent::Error(e) => {
                events.push(PlayerEvent::Error(e));
            }
            loonbox_audio::AudioEvent::BufferProgress(p) => {
                events.push(PlayerEvent::BufferProgress(p));
            }
        }
    }

    Ok(events)
}

/// Set 10-band EQ gains. Values in -1.0..1.0 range.
#[frb]
pub fn player_set_eq(bands: Vec<f32>) -> anyhow::Result<()> {
    if bands.len() != 10 {
        return Err(anyhow::anyhow!("Expected 10 EQ bands, got {}", bands.len()));
    }
    let mut arr = [0.0f32; 10];
    arr.copy_from_slice(&bands);
    with_engine(|engine| {
        engine
            .send_command(loonbox_audio::Command::SetEq(arr))
            .map_err(|e| anyhow::anyhow!("{}", e))
    })
}

// ─── Queue ───────────────────────────────────────────────────────────

#[frb]
pub fn queue_set(paths: Vec<String>, start_index: u32) -> anyhow::Result<()> {
    let _ = (paths, start_index);
    // TODO: Implement queue in Phase 3
    Ok(())
}

#[frb]
pub fn queue_next() -> anyhow::Result<()> {
    // TODO: Implement queue next
    Ok(())
}

#[frb]
pub fn queue_previous() -> anyhow::Result<()> {
    // TODO: Implement queue previous
    Ok(())
}

#[frb]
pub fn queue_shuffle(enabled: bool) -> anyhow::Result<()> {
    let _ = enabled;
    Ok(())
}

#[frb]
pub fn queue_repeat(mode: RepeatMode) -> anyhow::Result<()> {
    let _ = mode;
    Ok(())
}

// ─── Gapless & Crossfade ─────────────────────────────────────────────

#[frb]
pub fn player_set_crossfade(duration_ms: u32) -> anyhow::Result<()> {
    with_engine(|engine| {
        engine
            .send_command(loonbox_audio::Command::SetCrossfade(duration_ms))
            .map_err(|e| anyhow::anyhow!("{}", e))
    })
}

#[frb]
pub fn player_set_gapless(enabled: bool) -> anyhow::Result<()> {
    with_engine(|engine| {
        engine
            .send_command(loonbox_audio::Command::SetGapless(enabled))
            .map_err(|e| anyhow::anyhow!("{}", e))
    })
}

/// Tell the decoder which track to play next for gapless transition.
#[frb]
pub fn player_preload_next(path: String) -> anyhow::Result<()> {
    with_engine(|engine| {
        engine
            .send_command(loonbox_audio::Command::PreloadNext(path))
            .map_err(|e| anyhow::anyhow!("{}", e))
    })
}

// ─── Metadata ────────────────────────────────────────────────────────

#[frb]
pub fn metadata_read(path: String) -> anyhow::Result<TrackMetadata> {
    let meta = loonbox_metadata::reader::read_metadata(&path)
        .map_err(|e| anyhow::anyhow!("{}", e))?;

    Ok(TrackMetadata {
        path: meta.path,
        title: meta.title,
        artist: meta.artist,
        album_artist: meta.album_artist,
        album: meta.album,
        track_number: meta.track_number,
        disc_number: meta.disc_number,
        year: meta.year,
        genre: meta.genre,
        duration_ms: meta.duration_ms,
        has_album_art: meta.has_album_art,
        file_size: meta.file_size,
        sample_rate: meta.sample_rate,
        bit_depth: meta.bit_depth,
        channels: meta.channels,
        codec: meta.codec,
        musicbrainz_track_id: meta.musicbrainz_track_id,
        musicbrainz_artist_id: meta.musicbrainz_artist_id,
        replay_gain_track: meta.replay_gain_track,
        replay_gain_album: meta.replay_gain_album,
    })
}

#[frb]
pub fn metadata_batch_read(paths: Vec<String>) -> anyhow::Result<Vec<TrackMetadata>> {
    let results = loonbox_metadata::reader::batch_read(&paths);
    let mut out = Vec::with_capacity(results.len());
    for r in results {
        if let Ok(meta) = r {
            out.push(TrackMetadata {
                path: meta.path,
                title: meta.title,
                artist: meta.artist,
                album_artist: meta.album_artist,
                album: meta.album,
                track_number: meta.track_number,
                disc_number: meta.disc_number,
                year: meta.year,
                genre: meta.genre,
                duration_ms: meta.duration_ms,
                has_album_art: meta.has_album_art,
                file_size: meta.file_size,
                sample_rate: meta.sample_rate,
                bit_depth: meta.bit_depth,
                channels: meta.channels,
                codec: meta.codec,
                musicbrainz_track_id: meta.musicbrainz_track_id,
                musicbrainz_artist_id: meta.musicbrainz_artist_id,
                replay_gain_track: meta.replay_gain_track,
                replay_gain_album: meta.replay_gain_album,
            });
        }
    }
    Ok(out)
}

#[frb]
pub fn metadata_read_album_art(path: String) -> anyhow::Result<Option<Vec<u8>>> {
    loonbox_metadata::albumart::read_embedded_art(&path)
        .map_err(|e| anyhow::anyhow!("{}", e))
}

// ─── Audio Analysis ──────────────────────────────────────────────────

#[frb]
pub fn analyze_loudness(_path: String) -> anyhow::Result<LoudnessInfo> {
    // TODO: Implement loudness analysis (EBU R128)
    Ok(LoudnessInfo {
        integrated_lufs: -14.0,
        loudness_range: 7.0,
        true_peak: -1.0,
    })
}

#[frb]
pub fn analyze_bpm(_path: String) -> anyhow::Result<f32> {
    // TODO: Implement BPM detection
    Ok(120.0)
}

#[frb]
pub fn generate_waveform(_path: String, _samples: u32) -> anyhow::Result<Vec<f32>> {
    // TODO: Implement waveform generation
    Ok(vec![0.0; 200])
}
