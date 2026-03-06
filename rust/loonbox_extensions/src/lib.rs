//! LoonBox Extensions Runtime
//!
//! v1: Lua scripting via mlua (sandboxed)
//! v2: WASM via wasmtime (language-agnostic, strongest sandboxing)
//!
//! Extensions are loaded from the extensions directory and run in isolated
//! sandboxes with explicit permission grants.

pub mod runtime;

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
    pub min_loonbox_version: Option<String>,
    pub permissions: Vec<String>,
    pub entry: String,
    pub hooks: Option<Vec<String>>,
    pub ui: Option<ExtensionUi>,
    // Nest-ready fields (unused until The Nest launches)
    pub author_url: Option<String>,
    pub author_email: Option<String>,
    pub screenshots: Option<Vec<String>>,
    pub tags: Option<Vec<String>>,
    pub homepage_url: Option<String>,
    pub repository_url: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExtensionUi {
    pub slots: Option<Vec<UiSlot>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UiSlot {
    #[serde(rename = "type")]
    pub slot_type: String,
    pub panel_id: Option<String>,
    pub title: Option<String>,
    pub label: Option<String>,
    pub icon: Option<String>,
    pub content_type: Option<String>,
    pub target_types: Option<Vec<String>>,
    pub callback: Option<String>,
    pub update_interval_ms: Option<u64>,
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
