//! Public API surface for flutter_rust_bridge.
//!
//! All functions here are callable from Dart. flutter_rust_bridge v2
//! generates typed async Dart wrappers for each function.

use flutter_rust_bridge::frb;

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

// ─── Playback ────────────────────────────────────────────────────────

/// Load a track and return its info. Does not start playback.
#[frb]
pub fn player_load(path: String) -> anyhow::Result<TrackInfo> {
    let info = loonbox_audio::decoder::probe_track(&path)
        .map_err(|e| anyhow::anyhow!("{}", e))?;

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
    // TODO: Send play command to audio engine
    Ok(())
}

#[frb]
pub fn player_pause() -> anyhow::Result<()> {
    // TODO: Send pause command to audio engine
    Ok(())
}

#[frb]
pub fn player_stop() -> anyhow::Result<()> {
    // TODO: Send stop command to audio engine
    Ok(())
}

#[frb]
pub fn player_seek(position_ms: u64) -> anyhow::Result<()> {
    let _ = position_ms;
    // TODO: Send seek command to audio engine
    Ok(())
}

#[frb]
pub fn player_set_volume(volume: f32) -> anyhow::Result<()> {
    let _ = volume;
    // TODO: Send volume command to audio engine
    Ok(())
}

#[frb]
pub fn player_get_position() -> anyhow::Result<u64> {
    // TODO: Query current position from audio engine
    Ok(0)
}

#[frb]
pub fn player_get_state() -> anyhow::Result<PlayerState> {
    // TODO: Query current state from audio engine
    Ok(PlayerState::Stopped)
}

/// Set 10-band EQ gains. Values in -1.0..1.0 range.
#[frb]
pub fn player_set_eq(bands: Vec<f32>) -> anyhow::Result<()> {
    if bands.len() != 10 {
        return Err(anyhow::anyhow!("Expected 10 EQ bands, got {}", bands.len()));
    }
    // TODO: Send EQ command to audio engine
    Ok(())
}

// ─── Queue ───────────────────────────────────────────────────────────

#[frb]
pub fn queue_set(paths: Vec<String>, start_index: u32) -> anyhow::Result<()> {
    let _ = (paths, start_index);
    // TODO: Set queue in audio engine
    Ok(())
}

#[frb]
pub fn queue_next() -> anyhow::Result<()> {
    // TODO: Skip to next track
    Ok(())
}

#[frb]
pub fn queue_previous() -> anyhow::Result<()> {
    // TODO: Skip to previous track
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
    let _ = duration_ms;
    Ok(())
}

#[frb]
pub fn player_set_gapless(enabled: bool) -> anyhow::Result<()> {
    let _ = enabled;
    Ok(())
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
        match r {
            Ok(meta) => out.push(TrackMetadata {
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
            }),
            Err(_) => {} // Skip errors in batch mode
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
