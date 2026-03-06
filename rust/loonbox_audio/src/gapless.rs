//! Gapless playback support.
//!
//! Pre-buffers the next track while the current one is still playing.
//! Uses double-buffering: buffer A plays while buffer B pre-decodes the next track.
//! On transition, swap buffers with zero gap.

/// Gapless playback controller.
pub struct GaplessController {
    enabled: bool,
    next_track_path: Option<String>,
    pre_buffer_threshold_ms: u64,
}

impl GaplessController {
    pub fn new() -> Self {
        Self {
            enabled: true,
            next_track_path: None,
            pre_buffer_threshold_ms: 5000, // Start pre-buffering 5s before end
        }
    }

    pub fn set_enabled(&mut self, enabled: bool) {
        self.enabled = enabled;
    }

    pub fn is_enabled(&self) -> bool {
        self.enabled
    }

    /// Set the next track to pre-buffer.
    pub fn set_next_track(&mut self, path: Option<String>) {
        self.next_track_path = path;
    }

    /// Check if we should start pre-buffering based on current position.
    pub fn should_prebuffer(&self, position_ms: u64, duration_ms: u64) -> bool {
        self.enabled
            && self.next_track_path.is_some()
            && duration_ms > 0
            && position_ms + self.pre_buffer_threshold_ms >= duration_ms
    }

    pub fn take_next_track(&mut self) -> Option<String> {
        self.next_track_path.take()
    }
}
