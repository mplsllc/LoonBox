//! File system watcher using the `notify` crate.
//!
//! Watches registered directories for changes and emits FileChangeEvents.

use crate::scanner::is_audio_file;
use crate::FileChangeEvent;
use notify::{Config, Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use std::path::Path;
use std::sync::mpsc;

/// A running file watcher. Drop to stop watching.
pub struct FileWatcher {
    _watcher: RecommendedWatcher,
    rx: mpsc::Receiver<FileChangeEvent>,
}

impl FileWatcher {
    /// Create a new watcher on the given directory.
    pub fn new(path: &str, recursive: bool) -> Result<Self, String> {
        let (tx, rx) = mpsc::channel();

        let sender = tx.clone();
        let mut watcher = RecommendedWatcher::new(
            move |res: Result<Event, notify::Error>| {
                if let Ok(event) = res {
                    let changes = convert_event(event);
                    for change in changes {
                        let _ = sender.send(change);
                    }
                }
            },
            Config::default(),
        )
        .map_err(|e| format!("Failed to create watcher: {}", e))?;

        let mode = if recursive {
            RecursiveMode::Recursive
        } else {
            RecursiveMode::NonRecursive
        };

        watcher
            .watch(Path::new(path), mode)
            .map_err(|e| format!("Failed to watch {}: {}", path, e))?;

        Ok(Self {
            _watcher: watcher,
            rx,
        })
    }

    /// Try to receive pending file change events (non-blocking).
    pub fn try_recv(&self) -> Vec<FileChangeEvent> {
        let mut events = Vec::new();
        while let Ok(event) = self.rx.try_recv() {
            events.push(event);
        }
        events
    }
}

fn convert_event(event: Event) -> Vec<FileChangeEvent> {
    let mut changes = Vec::new();

    // Only process audio files
    let audio_paths: Vec<&std::path::Path> = event
        .paths
        .iter()
        .filter(|p| {
            p.to_str()
                .map(|s| is_audio_file(s))
                .unwrap_or(false)
        })
        .map(|p| p.as_path())
        .collect();

    if audio_paths.is_empty() {
        return changes;
    }

    match event.kind {
        EventKind::Create(_) => {
            for path in audio_paths {
                changes.push(FileChangeEvent::Added(
                    path.to_string_lossy().to_string(),
                ));
            }
        }
        EventKind::Modify(_) => {
            for path in audio_paths {
                changes.push(FileChangeEvent::Modified(
                    path.to_string_lossy().to_string(),
                ));
            }
        }
        EventKind::Remove(_) => {
            for path in audio_paths {
                changes.push(FileChangeEvent::Removed(
                    path.to_string_lossy().to_string(),
                ));
            }
        }
        _ => {}
    }

    changes
}
