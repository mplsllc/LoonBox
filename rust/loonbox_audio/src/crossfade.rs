//! Crossfade engine.
//!
//! Equal-power crossfade between outgoing and incoming tracks.
//! Configurable 0-12000ms duration.

/// Crossfade processor.
pub struct CrossfadeEngine {
    duration_ms: u32,
    enabled: bool,
}

impl CrossfadeEngine {
    pub fn new() -> Self {
        Self {
            duration_ms: 0,
            enabled: false,
        }
    }

    pub fn set_duration(&mut self, ms: u32) {
        self.duration_ms = ms.min(12000);
        self.enabled = ms > 0;
    }

    pub fn is_enabled(&self) -> bool {
        self.enabled
    }

    pub fn duration_ms(&self) -> u32 {
        self.duration_ms
    }

    /// Compute equal-power crossfade gains for a given progress (0.0 = start, 1.0 = end).
    /// Returns (outgoing_gain, incoming_gain).
    #[inline]
    pub fn gains(progress: f32) -> (f32, f32) {
        let p = progress.clamp(0.0, 1.0);
        let angle = p * std::f32::consts::FRAC_PI_2;
        let outgoing = angle.cos();
        let incoming = angle.sin();
        (outgoing, incoming)
    }

    /// Apply crossfade to two interleaved buffers.
    pub fn apply(
        outgoing: &mut [f32],
        incoming: &[f32],
        output: &mut [f32],
        progress_start: f32,
        progress_end: f32,
    ) {
        let len = output.len().min(outgoing.len()).min(incoming.len());
        if len == 0 {
            return;
        }

        for i in 0..len {
            let t = progress_start + (progress_end - progress_start) * (i as f32 / len as f32);
            let (og, ig) = Self::gains(t);
            output[i] = outgoing[i] * og + incoming[i] * ig;
        }
    }
}
