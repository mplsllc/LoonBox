//! Tag writing via lofty.

use crate::MetadataError;
use lofty::prelude::*;
use lofty::probe::Probe;
use lofty::tag::{ItemKey, ItemValue, TagItem};

/// Open a file and get a mutable reference to its primary tag,
/// creating one if none exists.
fn open_for_writing(path: &str) -> Result<lofty::file::TaggedFile, MetadataError> {
    let mut tagged_file = Probe::open(path)
        .map_err(|e| MetadataError::WriteError(e.to_string()))?
        .read()
        .map_err(|e| MetadataError::WriteError(e.to_string()))?;

    if tagged_file.primary_tag().is_none() {
        let tag_type = tagged_file.primary_tag_type();
        tagged_file.insert_tag(lofty::tag::Tag::new(tag_type));
    }

    Ok(tagged_file)
}

/// Write metadata fields to a file's tags.
pub fn write_metadata(
    path: &str,
    title: Option<&str>,
    artist: Option<&str>,
    album: Option<&str>,
    genre: Option<&str>,
    track_number: Option<u32>,
    disc_number: Option<u32>,
    year: Option<u32>,
    comment: Option<&str>,
) -> Result<(), MetadataError> {
    let mut tagged_file = open_for_writing(path)?;
    let tag = tagged_file.primary_tag_mut().unwrap();

    if let Some(v) = title { tag.set_title(v.to_string()); }
    if let Some(v) = artist { tag.set_artist(v.to_string()); }
    if let Some(v) = album { tag.set_album(v.to_string()); }
    if let Some(v) = genre { tag.set_genre(v.to_string()); }
    if let Some(v) = track_number { tag.set_track(v); }
    if let Some(v) = disc_number { tag.set_disk(v); }
    if let Some(v) = year { tag.set_year(v); }
    if let Some(v) = comment { tag.set_comment(v.to_string()); }

    tag.save_to_path(path, lofty::config::WriteOptions::default())
        .map_err(|e| MetadataError::WriteError(e.to_string()))?;

    Ok(())
}

/// Write only the MusicBrainz Recording ID tag to a file.
/// This is a lightweight flag — lofty handles the format-specific mapping
/// (TXXX for ID3v2, Vorbis comment, MP4 freeform atom).
pub fn write_musicbrainz_id(path: &str, track_id: &str) -> Result<(), MetadataError> {
    let mut tagged_file = open_for_writing(path)?;
    let tag = tagged_file.primary_tag_mut().unwrap();

    tag.insert(TagItem::new(
        ItemKey::MusicBrainzRecordingId,
        ItemValue::Text(track_id.to_string()),
    ));

    tag.save_to_path(path, lofty::config::WriteOptions::default())
        .map_err(|e| MetadataError::WriteError(e.to_string()))?;

    Ok(())
}
