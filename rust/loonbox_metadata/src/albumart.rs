//! Album art extraction and caching.
//!
//! Fetcher pipeline (from Nightingale):
//! 1. Embedded metadata (ID3 APIC / Vorbis METADATA_BLOCK_PICTURE)
//! 2. File-based (cover.jpg, folder.jpg, etc. in same directory)
//! 3. Remote (MusicBrainz, Last.fm — deferred to extension system)

use crate::MetadataError;

/// Names to look for when searching for file-based album art.
const COVER_FILENAMES: &[&str] = &[
    "cover", "folder", "front", "album", "art", "thumb",
];
const IMAGE_EXTENSIONS: &[&str] = &["jpg", "jpeg", "png", "webp", "bmp"];

/// Extract embedded album art from a file. Returns raw image bytes.
pub fn read_embedded_art(path: &str) -> Result<Option<Vec<u8>>, MetadataError> {
    use lofty::prelude::*;
    use lofty::probe::Probe;

    let tagged_file = Probe::open(path)
        .map_err(|e| MetadataError::ReadError(e.to_string()))?
        .read()
        .map_err(|e| MetadataError::ReadError(e.to_string()))?;

    let tag = tagged_file.primary_tag().or_else(|| tagged_file.first_tag());

    if let Some(tag) = tag {
        if let Some(pic) = tag.pictures().first() {
            return Ok(Some(pic.data().to_vec()));
        }
    }

    Ok(None)
}

/// Search for file-based album art in the same directory as the track.
pub fn find_file_art(track_path: &str) -> Option<String> {
    let dir = std::path::Path::new(track_path).parent()?;

    for entry in std::fs::read_dir(dir).ok()?.flatten() {
        let path = entry.path();
        if !path.is_file() {
            continue;
        }

        let stem = path.file_stem()?.to_str()?.to_lowercase();
        let ext = path.extension()?.to_str()?.to_lowercase();

        if COVER_FILENAMES.contains(&stem.as_str()) && IMAGE_EXTENSIONS.contains(&ext.as_str()) {
            return Some(path.to_string_lossy().to_string());
        }
    }

    None
}
