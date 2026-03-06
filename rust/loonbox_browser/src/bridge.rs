//! JS bridge types and command definitions.
//!
//! The JS bridge allows trusted web pages (The Nest, Tremolo) to
//! communicate with the LoonBox player via postMessage.
//!
//! Command whitelist (extensible — not a closed enum):
//! - player.play, player.pause, player.stop, player.seek
//! - player.getState, player.getPosition
//! - nest.installFeather, nest.installExtension
//! - tremolo.purchase
//! - app.navigate
//! - browser.loadUrl
//!
//! The actual dispatch happens in Flutter (not here), because the
//! AudioService interface is Dart-side. This module defines the
//! shared types and validation logic.

use serde::{Deserialize, Serialize};

/// Incoming message from a trusted web page.
#[derive(Debug, Deserialize)]
pub struct BridgeMessage {
    pub id: u64,
    pub cmd: String,
    #[serde(default)]
    pub args: serde_json::Value,
}

/// Outgoing response back to the web page.
#[derive(Debug, Serialize)]
pub struct BridgeResponse {
    #[serde(rename = "type")]
    pub msg_type: String, // always "response"
    pub id: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

/// Trusted domains that get JS bridge access.
pub const TRUSTED_DOMAINS: &[&str] = &[
    "loonbox.app",
    "nest.loonbox.app",
    "tremolo.app",
];

/// Check if a URL belongs to a trusted domain.
pub fn is_trusted_url(url: &str) -> bool {
    TRUSTED_DOMAINS.iter().any(|domain| {
        url.contains(domain)
    })
}
