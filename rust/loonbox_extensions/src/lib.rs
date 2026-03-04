//! LoonBox Extensions Runtime
//!
//! v1: Lua scripting via mlua (sandboxed)
//! v2: WASM via wasmtime (language-agnostic, strongest sandboxing)
//!
//! Extensions are loaded from the extensions directory and run in isolated
//! sandboxes with explicit permission grants.

use serde::{Deserialize, Serialize};

/// Extension manifest (parsed from extension.json in each extension directory).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExtensionManifest {
    pub id: String,
    pub name: String,
    pub version: String,
    pub description: Option<String>,
    pub author: Option<String>,
    pub license: Option<String>,
    pub loonbox_version: Option<String>,
    pub permissions: Vec<String>,
    pub entry: String,
    pub ui: Option<ExtensionUi>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExtensionUi {
    pub panels: Option<Vec<ExtensionPanel>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExtensionPanel {
    pub id: String,
    pub title: String,
    pub location: String,
}

/// Permission types for extension sandboxing.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Permission {
    NetworkAll,
    NetworkDomain(String),
    PlayerRead,
    PlayerControl,
    LibraryRead,
    LibraryWrite,
    UiPanel,
    UiContextMenu,
    UiToolbar,
    Storage,
    MetadataRead,
    MetadataWrite,
}

impl Permission {
    pub fn parse(s: &str) -> Option<Self> {
        let parts: Vec<&str> = s.splitn(2, ':').collect();
        match parts.as_slice() {
            ["network", "*"] => Some(Self::NetworkAll),
            ["network", domain] => Some(Self::NetworkDomain(domain.to_string())),
            ["player", "read"] => Some(Self::PlayerRead),
            ["player", "control"] => Some(Self::PlayerControl),
            ["library", "read"] => Some(Self::LibraryRead),
            ["library", "write"] => Some(Self::LibraryWrite),
            ["ui", "panel"] => Some(Self::UiPanel),
            ["ui", "context_menu"] => Some(Self::UiContextMenu),
            ["ui", "toolbar"] => Some(Self::UiToolbar),
            ["storage"] => Some(Self::Storage),
            ["metadata", "read"] => Some(Self::MetadataRead),
            ["metadata", "write"] => Some(Self::MetadataWrite),
            _ => None,
        }
    }
}
