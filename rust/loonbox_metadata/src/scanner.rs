//! Directory scanner for music files.
//!
//! Walks a directory tree, filters by audio extensions, reads metadata
//! in parallel using rayon, and streams ScanEvent results.

use crate::{reader, ScanEvent, TrackMetadata};
use rayon::prelude::*;
use std::path::Path;
use std::time::Instant;
use walkdir::WalkDir;

/// Audio file extensions we recognize.
const AUDIO_EXTENSIONS: &[&str] = &[
    "mp3", "flac", "ogg", "opus", "wav", "aac", "m4a", "wma", "aiff", "ape", "mpc", "wv",
];

/// Scan a directory for audio files and return metadata.
/// Results are batched and returned as a Vec of ScanEvents.
pub fn scan_directory(path: &str, recursive: bool) -> Vec<ScanEvent> {
    let start = Instant::now();
    let mut events = Vec::new();

    // Collect all audio file paths
    let walker = if recursive {
        WalkDir::new(path)
    } else {
        WalkDir::new(path).max_depth(1)
    };

    let audio_paths: Vec<String> = walker
        .into_iter()
        .filter_map(|entry| entry.ok())
        .filter(|entry| {
            entry.file_type().is_file()
                && entry
                    .path()
                    .extension()
                    .and_then(|ext| ext.to_str())
                    .map(|ext| AUDIO_EXTENSIONS.contains(&ext.to_lowercase().as_str()))
                    .unwrap_or(false)
        })
        .map(|entry| entry.path().to_string_lossy().to_string())
        .collect();

    let total = audio_paths.len() as u32;

    // Read metadata in parallel batches
    let results: Vec<(String, Result<TrackMetadata, String>)> = audio_paths
        .par_iter()
        .map(|p| {
            let result = reader::read_metadata(p).map_err(|e| e.to_string());
            (p.clone(), result)
        })
        .collect();

    let mut scanned = 0u32;
    for (file_path, result) in results {
        scanned += 1;
        match result {
            Ok(meta) => events.push(ScanEvent::Found(meta)),
            Err(e) => events.push(ScanEvent::Error {
                path: file_path,
                error: e,
            }),
        }

        // Emit progress every 100 files
        if scanned % 100 == 0 || scanned == total {
            events.push(ScanEvent::Progress { scanned, total });
        }
    }

    let duration_ms = start.elapsed().as_millis() as u64;
    events.push(ScanEvent::Complete {
        total: scanned,
        duration_ms,
    });

    events
}

/// Scan a directory and return just the file paths (fast, no metadata reading).
pub fn find_audio_files(path: &str, recursive: bool) -> Vec<String> {
    let walker = if recursive {
        WalkDir::new(path)
    } else {
        WalkDir::new(path).max_depth(1)
    };

    walker
        .into_iter()
        .filter_map(|entry| entry.ok())
        .filter(|entry| {
            entry.file_type().is_file()
                && entry
                    .path()
                    .extension()
                    .and_then(|ext| ext.to_str())
                    .map(|ext| AUDIO_EXTENSIONS.contains(&ext.to_lowercase().as_str()))
                    .unwrap_or(false)
        })
        .map(|entry| entry.path().to_string_lossy().to_string())
        .collect()
}

/// Check if a path is an audio file we support.
pub fn is_audio_file(path: &str) -> bool {
    Path::new(path)
        .extension()
        .and_then(|ext| ext.to_str())
        .map(|ext| AUDIO_EXTENSIONS.contains(&ext.to_lowercase().as_str()))
        .unwrap_or(false)
}
