//! Tag reading via lofty.
//!
//! Supports: ID3v1, ID3v2.2/2.3/2.4, Vorbis Comments, RIFF INFO,
//! MP4/iTunes atoms, APE tags, MusicBrainz extended tags.

use crate::{MetadataError, TrackMetadata};

/// Read metadata from a single file.
pub fn read_metadata(path: &str) -> Result<TrackMetadata, MetadataError> {
    use lofty::prelude::*;
    use lofty::probe::Probe;

    let tagged_file = Probe::open(path)
        .map_err(|e| MetadataError::ReadError(e.to_string()))?
        .read()
        .map_err(|e| MetadataError::ReadError(e.to_string()))?;

    let properties = tagged_file.properties();
    let tag = tagged_file.primary_tag().or_else(|| tagged_file.first_tag());

    let file_size = std::fs::metadata(path)
        .map(|m| m.len())
        .unwrap_or(0);

    let mut meta = TrackMetadata {
        path: path.to_string(),
        file_size,
        duration_ms: Some(properties.duration().as_millis() as u64),
        sample_rate: properties.sample_rate(),
        bit_depth: properties.bit_depth().map(|b| b as u16),
        channels: properties.channels().map(|c| c as u16),
        ..Default::default()
    };

    if let Some(tag) = tag {
        use lofty::tag::ItemKey;

        meta.title = tag.title().map(|s| s.to_string());
        meta.artist = tag.artist().map(|s| s.to_string());
        meta.album = tag.album().map(|s| s.to_string());
        meta.genre = tag.genre().map(|s| s.to_string());
        meta.track_number = tag.track();
        meta.disc_number = tag.disk();
        meta.year = tag.year();
        meta.comment = tag.comment().map(|s| s.to_string());
        meta.has_album_art = !tag.pictures().is_empty();

        // MusicBrainz IDs — lofty handles format-specific mapping
        // (TXXX for ID3v2, Vorbis comment, MP4 freeform atom)
        meta.musicbrainz_track_id = tag
            .get_string(&ItemKey::MusicBrainzRecordingId)
            .map(|s| s.to_string());
        meta.musicbrainz_artist_id = tag
            .get_string(&ItemKey::MusicBrainzArtistId)
            .map(|s| s.to_string());
    }

    Ok(meta)
}

/// Read metadata from multiple files in parallel using rayon.
pub fn batch_read(paths: &[String]) -> Vec<Result<TrackMetadata, MetadataError>> {
    use rayon::prelude::*;

    paths
        .par_iter()
        .map(|p| read_metadata(p))
        .collect()
}
