//! LoonBox Metadata — tag reading/writing, album art, directory scanning.

pub mod reader;
pub mod writer;
pub mod albumart;

use thiserror::Error;

#[derive(Error, Debug)]
pub enum MetadataError {
    #[error("File not found: {0}")]
    FileNotFound(String),
    #[error("Tag read error: {0}")]
    ReadError(String),
    #[error("Tag write error: {0}")]
    WriteError(String),
    #[error("Unsupported format: {0}")]
    UnsupportedFormat(String),
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

/// Track metadata extracted from file tags.
#[derive(Debug, Clone, Default)]
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
    pub comment: Option<String>,
    pub composer: Option<String>,
    pub lyrics: Option<String>,
    pub musicbrainz_track_id: Option<String>,
    pub musicbrainz_artist_id: Option<String>,
    pub replay_gain_track: Option<f32>,
    pub replay_gain_album: Option<f32>,
    pub bpm: Option<f32>,
}

/// Scan event streamed during directory scanning.
#[derive(Debug, Clone)]
pub enum ScanEvent {
    Found(TrackMetadata),
    Progress { scanned: u32, total: u32 },
    Complete { total: u32, duration_ms: u64 },
    Error { path: String, error: String },
}

/// File change event from watch folder.
#[derive(Debug, Clone)]
pub enum FileChangeEvent {
    Added(String),
    Removed(String),
    Modified(String),
    Renamed { old: String, new: String },
}
