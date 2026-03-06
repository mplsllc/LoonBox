//! Public API surface for flutter_rust_bridge.
//!
//! All functions here are callable from Dart. flutter_rust_bridge v2
//! generates typed async Dart wrappers for each function.

use flutter_rust_bridge::frb;
use once_cell::sync::Lazy;
use parking_lot::Mutex;

use std::collections::HashMap;

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
    TrackFinished,
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
                events.push(PlayerEvent::TrackFinished);
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
    Ok(convert_metadata(meta))
}

#[frb]
pub fn metadata_batch_read(paths: Vec<String>) -> anyhow::Result<Vec<TrackMetadata>> {
    let results = loonbox_metadata::reader::batch_read(&paths);
    Ok(results.into_iter().filter_map(|r| r.ok()).map(convert_metadata).collect())
}

#[frb]
pub fn metadata_read_album_art(path: String) -> anyhow::Result<Option<Vec<u8>>> {
    loonbox_metadata::albumart::read_embedded_art(&path)
        .map_err(|e| anyhow::anyhow!("{}", e))
}

/// Find file-based album art (cover.jpg, folder.png, etc.) in the same directory.
#[frb]
pub fn metadata_find_file_art(track_path: String) -> anyhow::Result<Option<String>> {
    Ok(loonbox_metadata::albumart::find_file_art(&track_path))
}

#[frb]
pub fn metadata_write(
    path: String,
    title: Option<String>,
    artist: Option<String>,
    album: Option<String>,
    genre: Option<String>,
    track_number: Option<u32>,
    disc_number: Option<u32>,
    year: Option<u32>,
    comment: Option<String>,
) -> anyhow::Result<()> {
    loonbox_metadata::writer::write_metadata(
        &path,
        title.as_deref(),
        artist.as_deref(),
        album.as_deref(),
        genre.as_deref(),
        track_number,
        disc_number,
        year,
        comment.as_deref(),
    )
    .map_err(|e| anyhow::anyhow!("{}", e))
}

#[frb]
pub fn metadata_write_mb_id(path: String, track_id: String) -> anyhow::Result<()> {
    loonbox_metadata::writer::write_musicbrainz_id(&path, &track_id)
        .map_err(|e| anyhow::anyhow!("{}", e))
}

// ─── Library Scanning ────────────────────────────────────────────────

/// Convert loonbox_metadata::TrackMetadata to bridge TrackMetadata.
fn convert_metadata(meta: loonbox_metadata::TrackMetadata) -> TrackMetadata {
    TrackMetadata {
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
    }
}

/// Scan a directory for audio files and return metadata + progress events.
#[frb]
pub fn library_scan(path: String, recursive: bool) -> anyhow::Result<Vec<ScanEvent>> {
    let raw = loonbox_metadata::scanner::scan_directory(&path, recursive);
    let events = raw
        .into_iter()
        .map(|e| match e {
            loonbox_metadata::ScanEvent::Found(meta) => ScanEvent::Found(convert_metadata(meta)),
            loonbox_metadata::ScanEvent::Progress { scanned, total } => {
                ScanEvent::Progress { scanned, total }
            }
            loonbox_metadata::ScanEvent::Complete { total, duration_ms } => {
                ScanEvent::Complete { total, duration_ms }
            }
            loonbox_metadata::ScanEvent::Error { path, error } => {
                ScanEvent::Error { path, error }
            }
        })
        .collect();
    Ok(events)
}

/// Fast scan: return just audio file paths without reading metadata.
#[frb]
pub fn library_find_files(path: String, recursive: bool) -> anyhow::Result<Vec<String>> {
    Ok(loonbox_metadata::scanner::find_audio_files(&path, recursive))
}

// ─── File Watcher ────────────────────────────────────────────────────

use std::sync::atomic::{AtomicU32, Ordering};

/// Next watcher ID counter.
static NEXT_WATCHER_ID: AtomicU32 = AtomicU32::new(1);

/// Active file watchers, keyed by watcher ID.
static WATCHERS: Lazy<Mutex<HashMap<u32, loonbox_metadata::watcher::FileWatcher>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

/// Start watching a directory for file changes. Returns a watcher ID.
#[frb]
pub fn watcher_start(path: String, recursive: bool) -> anyhow::Result<u32> {
    let watcher = loonbox_metadata::watcher::FileWatcher::new(&path, recursive)
        .map_err(|e| anyhow::anyhow!("{}", e))?;
    let id = NEXT_WATCHER_ID.fetch_add(1, Ordering::Relaxed);
    WATCHERS.lock().insert(id, watcher);
    Ok(id)
}

/// Stop watching a directory. Pass the ID returned by watcher_start.
#[frb]
pub fn watcher_stop(watcher_id: u32) -> anyhow::Result<()> {
    let removed = WATCHERS.lock().remove(&watcher_id);
    if removed.is_none() {
        return Err(anyhow::anyhow!("No watcher with ID {}", watcher_id));
    }
    Ok(())
}

/// Poll pending file change events from a watcher.
#[frb]
pub fn watcher_poll_events(watcher_id: u32) -> anyhow::Result<Vec<FileChangeEvent>> {
    let watchers = WATCHERS.lock();
    let watcher = watchers
        .get(&watcher_id)
        .ok_or_else(|| anyhow::anyhow!("No watcher with ID {}", watcher_id))?;

    let raw = watcher.try_recv();
    let events = raw
        .into_iter()
        .map(|e| match e {
            loonbox_metadata::FileChangeEvent::Added(p) => FileChangeEvent::Added(p),
            loonbox_metadata::FileChangeEvent::Removed(p) => FileChangeEvent::Removed(p),
            loonbox_metadata::FileChangeEvent::Modified(p) => FileChangeEvent::Modified(p),
            loonbox_metadata::FileChangeEvent::Renamed { old, new } => {
                FileChangeEvent::Renamed {
                    old_path: old,
                    new_path: new,
                }
            }
        })
        .collect();
    Ok(events)
}

/// Stop all active watchers.
#[frb]
pub fn watcher_stop_all() -> anyhow::Result<()> {
    WATCHERS.lock().clear();
    Ok(())
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

// ─── Visualization ───────────────────────────────────────────────────

#[frb]
#[derive(Debug, Clone)]
pub struct VisualizationData {
    /// Mono waveform samples (-1.0 to 1.0), 256 samples.
    pub waveform: Vec<f32>,
    /// Spectrum magnitude bins (log-frequency, 0.0 to 1.0), 64 bins.
    pub spectrum: Vec<f32>,
    /// Left channel peak level (0.0 to 1.0).
    pub peak_left: f32,
    /// Right channel peak level (0.0 to 1.0).
    pub peak_right: f32,
}

/// Get current visualization data (waveform + spectrum + peaks).
/// Call at ~30-60fps from Dart for smooth animation.
#[frb]
pub fn player_get_visualization_data() -> anyhow::Result<VisualizationData> {
    ensure_engine()?;
    let guard = ENGINE.lock();
    let engine = guard
        .as_ref()
        .ok_or_else(|| anyhow::anyhow!("Engine not initialized"))?;

    let snap = engine.visualization.snapshot();
    Ok(VisualizationData {
        waveform: snap.waveform,
        spectrum: snap.spectrum,
        peak_left: snap.peak_left,
        peak_right: snap.peak_right,
    })
}

/// Enable or disable visualization data capture.
/// Disabled by default to save CPU when not needed.
#[frb]
pub fn player_set_visualization_enabled(enabled: bool) -> anyhow::Result<()> {
    ensure_engine()?;
    let guard = ENGINE.lock();
    let engine = guard
        .as_ref()
        .ok_or_else(|| anyhow::anyhow!("Engine not initialized"))?;
    engine.visualization.set_enabled(enabled);
    Ok(())
}

// ─── Extensions ──────────────────────────────────────────────────────

static EXTENSIONS: Lazy<Mutex<HashMap<String, loonbox_extensions::runtime::ExtensionInstance>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

#[frb]
#[derive(Debug, Clone)]
pub struct ExtensionInfo {
    pub id: String,
    pub name: String,
    pub version: String,
    pub description: String,
    pub author: String,
    pub permissions: Vec<String>,
    pub hooks: Vec<String>,
}

/// Load an extension from a directory path.
#[frb]
pub fn extension_load(path: String) -> anyhow::Result<ExtensionInfo> {
    let instance = loonbox_extensions::runtime::ExtensionInstance::load(std::path::Path::new(&path))
        .map_err(|e| anyhow::anyhow!("{}", e))?;

    let info = ExtensionInfo {
        id: instance.manifest.id.clone(),
        name: instance.manifest.name.clone(),
        version: instance.manifest.version.clone(),
        description: instance.manifest.description.clone().unwrap_or_default(),
        author: instance.manifest.author.clone().unwrap_or_default(),
        permissions: instance.manifest.permissions.clone(),
        hooks: instance.manifest.hooks.clone().unwrap_or_default(),
    };

    EXTENSIONS.lock().insert(info.id.clone(), instance);
    Ok(info)
}

/// Unload an extension by ID.
#[frb]
pub fn extension_unload(id: String) -> anyhow::Result<()> {
    EXTENSIONS.lock().remove(&id);
    Ok(())
}

/// List all loaded extension IDs.
#[frb]
pub fn extension_list() -> Vec<String> {
    EXTENSIONS.lock().keys().cloned().collect()
}

/// Dispatch a Call (event hook) to all loaded extensions.
#[frb]
pub fn extension_dispatch_call(call_name: String, args_json: String) -> anyhow::Result<Vec<String>> {
    let args: serde_json::Value = serde_json::from_str(&args_json)
        .unwrap_or(serde_json::Value::Null);

    let call = match call_name.as_str() {
        "on_track_change" => loonbox_extensions::runtime::ExtensionCall::TrackChange {
            title: args["title"].as_str().unwrap_or("").to_string(),
            artist: args["artist"].as_str().unwrap_or("").to_string(),
            album: args["album"].as_str().unwrap_or("").to_string(),
            file_path: args["file_path"].as_str().unwrap_or("").to_string(),
            duration_ms: args["duration_ms"].as_u64().unwrap_or(0),
        },
        "on_playback_start" => loonbox_extensions::runtime::ExtensionCall::PlaybackStart,
        "on_playback_stop" => loonbox_extensions::runtime::ExtensionCall::PlaybackStop,
        "on_track_end" => loonbox_extensions::runtime::ExtensionCall::TrackEnd {
            title: args["title"].as_str().unwrap_or("").to_string(),
            artist: args["artist"].as_str().unwrap_or("").to_string(),
            album: args["album"].as_str().unwrap_or("").to_string(),
            duration_ms: args["duration_ms"].as_u64().unwrap_or(0),
            played_ms: args["played_ms"].as_u64().unwrap_or(0),
        },
        "on_library_scan_complete" => loonbox_extensions::runtime::ExtensionCall::LibraryScanComplete {
            total: args["total"].as_u64().unwrap_or(0),
        },
        "on_app_start" => loonbox_extensions::runtime::ExtensionCall::AppStart,
        "on_app_exit" => loonbox_extensions::runtime::ExtensionCall::AppExit,
        _ => return Err(anyhow::anyhow!("Unknown call: {}", call_name)),
    };

    let extensions = EXTENSIONS.lock();
    let mut results = Vec::new();
    for instance in extensions.values() {
        if let Ok(Some(result)) = instance.dispatch_call(&call) {
            results.push(result);
        }
    }
    Ok(results)
}

/// Call a specific function in a specific extension.
#[frb]
pub fn extension_call_function(
    extension_id: String,
    function_name: String,
    args_json: String,
) -> anyhow::Result<String> {
    let extensions = EXTENSIONS.lock();
    let instance = extensions
        .get(&extension_id)
        .ok_or_else(|| anyhow::anyhow!("Extension '{}' not loaded", extension_id))?;
    instance
        .call_function(&function_name, &args_json)
        .map_err(|e| anyhow::anyhow!("{}", e))
}

/// Get an extension's storage contents (for persisting to DB).
#[frb]
pub fn extension_get_storage(extension_id: String) -> anyhow::Result<Vec<(String, String)>> {
    let extensions = EXTENSIONS.lock();
    let instance = extensions
        .get(&extension_id)
        .ok_or_else(|| anyhow::anyhow!("Extension '{}' not loaded", extension_id))?;
    Ok(instance.get_storage().into_iter().collect())
}

/// Restore an extension's storage from DB data.
#[frb]
pub fn extension_set_storage(
    extension_id: String,
    data: Vec<(String, String)>,
) -> anyhow::Result<()> {
    let extensions = EXTENSIONS.lock();
    let instance = extensions
        .get(&extension_id)
        .ok_or_else(|| anyhow::anyhow!("Extension '{}' not loaded", extension_id))?;
    instance.set_storage(data.into_iter().collect());
    Ok(())
}

// ─── Browser ─────────────────────────────────────────────────────────

/// Start the browser filtering proxy. Returns the port number.
#[frb]
pub fn browser_start_proxy(cache_dir: String) -> anyhow::Result<u32> {
    let port = loonbox_browser::start_proxy(&cache_dir)?;
    Ok(port as u32)
}

/// Stop the browser filtering proxy.
#[frb]
pub fn browser_stop_proxy() {
    loonbox_browser::stop_proxy();
}

/// Get the current proxy port (0 if not running).
#[frb]
pub fn browser_get_proxy_port() -> u32 {
    loonbox_browser::get_proxy_port() as u32
}

/// Verify a package file's SHA-256 hash matches the expected hex string.
#[frb]
pub fn browser_verify_package(
    package_path: String,
    expected_sha256: String,
) -> anyhow::Result<bool> {
    loonbox_browser::signatures::verify_package(&package_path, &expected_sha256)
}

/// Update adblock filter lists from the network.
#[frb]
pub fn browser_update_filter_lists() -> anyhow::Result<()> {
    loonbox_browser::update_filter_lists()
}

/// Get adblock filter stats as JSON.
#[frb]
pub fn browser_get_filter_stats() -> String {
    loonbox_browser::get_filter_stats()
}
