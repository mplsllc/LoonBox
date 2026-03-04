//! Symphonia-based audio decoder.
//!
//! Runs on the decoder thread. Reads audio files, decodes to PCM,
//! and pushes samples into the ring buffer for the audio thread.

use crate::{AudioError, TrackInfo};

/// Decode a file and return track information.
///
/// Full implementation will:
/// 1. Open file with Symphonia MediaSourceStream
/// 2. Probe format/codec
/// 3. Create decoder
/// 4. Read packets and decode to PCM f32
/// 5. Push through DSP pipeline (EQ, ReplayGain, crossfade)
/// 6. Write to ring buffer
pub fn probe_track(path: &str) -> Result<TrackInfo, AudioError> {
    use symphonia::core::io::MediaSourceStream;
    use symphonia::core::probe::Hint;

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
