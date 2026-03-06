/// Playback state machine.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PlayerState {
    Stopped,
    Loading,
    Playing,
    Paused,
    Error(String),
}

impl std::fmt::Display for PlayerState {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Stopped => write!(f, "stopped"),
            Self::Loading => write!(f, "loading"),
            Self::Playing => write!(f, "playing"),
            Self::Paused => write!(f, "paused"),
            Self::Error(e) => write!(f, "error: {}", e),
        }
    }
}
