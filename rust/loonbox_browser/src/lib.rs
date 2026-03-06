//! LoonBox embedded browser — filtering proxy + adblock + JS bridge.
//!
//! Tokio is encapsulated entirely inside this crate.
//! The public API surface is 100% synchronous.
//!
//! The adblock engine lives on the proxy's single-threaded runtime
//! (it's !Send). Cross-thread operations use channels.

pub mod proxy;
pub mod filter;
pub mod bridge;
pub mod signatures;

use once_cell::sync::Lazy;
use parking_lot::Mutex;
use proxy::ProxyCommand;

/// Internal state for the browser subsystem.
pub struct BrowserState {
    pub server: Option<proxy::ProxyServer>,
}

impl Default for BrowserState {
    fn default() -> Self {
        Self { server: None }
    }
}

pub(crate) static BROWSER: Lazy<Mutex<BrowserState>> =
    Lazy::new(|| Mutex::new(BrowserState::default()));

/// Start the filtering proxy. Returns the bound port. Idempotent.
pub fn start_proxy(cache_dir: &str) -> anyhow::Result<u16> {
    let mut state = BROWSER.lock();
    if let Some(ref server) = state.server {
        return Ok(server.port);
    }
    let server = proxy::start(cache_dir)?;
    let port = server.port;
    state.server = Some(server);
    Ok(port)
}

/// Stop the proxy. Safe to call if not started.
pub fn stop_proxy() {
    let mut state = BROWSER.lock();
    if let Some(server) = state.server.take() {
        server.shutdown();
    }
}

/// Returns the proxy port, or 0 if not started.
pub fn get_proxy_port() -> u16 {
    let state = BROWSER.lock();
    state.server.as_ref().map(|s| s.port).unwrap_or(0)
}

/// Update filter lists from network. Blocks until complete.
pub fn update_filter_lists() -> anyhow::Result<()> {
    let state = BROWSER.lock();
    let cmd_tx = state.server.as_ref()
        .ok_or_else(|| anyhow::anyhow!("Browser not started"))?
        .cmd_tx.clone();
    drop(state);

    let (reply_tx, reply_rx) = tokio::sync::oneshot::channel();
    cmd_tx.send(ProxyCommand::UpdateFilters(reply_tx))
        .map_err(|_| anyhow::anyhow!("Proxy thread not running"))?;

    // Block the calling thread until the proxy thread completes the update
    reply_rx.blocking_recv()
        .map_err(|_| anyhow::anyhow!("Proxy thread dropped reply channel"))?
}

/// Get filter stats as JSON string.
pub fn get_filter_stats() -> String {
    let state = BROWSER.lock();
    let cmd_tx = match state.server.as_ref() {
        Some(s) => s.cmd_tx.clone(),
        None => return r#"{"rule_count":0,"last_updated":0,"enabled":false}"#.to_string(),
    };
    drop(state);

    let (reply_tx, reply_rx) = tokio::sync::oneshot::channel();
    if cmd_tx.send(ProxyCommand::GetStats(reply_tx)).is_err() {
        return r#"{"rule_count":0,"last_updated":0,"enabled":false}"#.to_string();
    }

    reply_rx.blocking_recv()
        .unwrap_or_else(|_| r#"{"rule_count":0,"last_updated":0,"enabled":false}"#.to_string())
}
