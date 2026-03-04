//! Tag writing via lofty.

use crate::MetadataError;

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
    use lofty::prelude::*;
    use lofty::probe::Probe;

    let mut tagged_file = Probe::open(path)
        .map_err(|e| MetadataError::WriteError(e.to_string()))?
        .read()
        .map_err(|e| MetadataError::WriteError(e.to_string()))?;

    let tag = match tagged_file.primary_tag_mut() {
        Some(t) => t,
        None => {
            // Insert tag of the most fitting type for this file
            let tag_type = tagged_file.primary_tag_type();
            tagged_file.insert_tag(lofty::tag::Tag::new(tag_type));
            tagged_file.primary_tag_mut().unwrap()
        }
    };

    if let Some(v) = title { tag.set_title(v.to_string()); }
    if let Some(v) = artist { tag.set_artist(v.to_string()); }
    if let Some(v) = album { tag.set_album(v.to_string()); }
    if let Some(v) = genre { tag.set_genre(v.to_string()); }
    if let Some(v) = track_number { tag.set_track(v); }
    if let Some(v) = disc_number { tag.set_disk(v); }
    if let Some(v) = year { tag.set_year(v); }
    if let Some(v) = comment { tag.set_comment(v.to_string()); }

    tag.save_to_path(path)
        .map_err(|e| MetadataError::WriteError(e.to_string()))?;

    Ok(())
}
