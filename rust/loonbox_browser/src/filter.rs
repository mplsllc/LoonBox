//! Adblock filter engine.
//!
//! Wraps the Brave `adblock` crate. Ships a pre-compiled EasyList
//! binary via `include_bytes!()`, with runtime updates cached to disk.
//!
//! **Thread model:** `adblock::Engine` is `!Send + !Sync` (uses internal Rc/RefCell).
//! All engine access happens on the proxy's single-threaded Tokio runtime via
//! `spawn_local`. The `AdblockFilter` struct lives entirely on that thread.

use std::cell::RefCell;
use std::path::PathBuf;
use adblock::engine::Engine;
use adblock::lists::{FilterSet, ParseOptions};
use adblock::request::Request;

/// Adblock filter engine wrapper.
/// NOT Send/Sync — lives on the proxy's single-threaded runtime.
pub struct AdblockFilter {
    engine: RefCell<Engine>,
    rule_count: RefCell<u64>,
    last_updated: RefCell<u64>,
    cache_dir: PathBuf,
}

impl AdblockFilter {
    /// Create a new filter engine. Tries to load from disk cache first,
    /// falls back to bundled snapshot, then empty engine.
    pub fn new(cache_dir: &str) -> Self {
        let cache_dir = PathBuf::from(cache_dir);
        let cache_path = cache_dir.join("filter_lists").join("engine.dat");

        let mut engine = Engine::default();
        let mut rule_count = 0u64;
        let mut last_updated = 0u64;

        // Try loading cached binary from disk
        if cache_path.exists() {
            if let Ok(data) = std::fs::read(&cache_path) {
                if engine.deserialize(&data).is_ok() {
                    log::info!("Loaded adblock engine from cache");
                    if let Ok(meta) = std::fs::read_to_string(cache_path.with_extension("meta")) {
                        if let Ok(m) = serde_json::from_str::<FilterMeta>(&meta) {
                            rule_count = m.rule_count;
                            last_updated = m.last_updated;
                        }
                    }
                } else {
                    log::warn!("Cached adblock engine failed to deserialize, starting fresh");
                    engine = Engine::default();
                }
            }
        }

        // TODO: If still empty, load from BUNDLED_DAT via include_bytes!()

        AdblockFilter {
            engine: RefCell::new(engine),
            rule_count: RefCell::new(rule_count),
            last_updated: RefCell::new(last_updated),
            cache_dir,
        }
    }

    /// Check if a URL should be blocked.
    pub fn should_block(&self, url: &str, source_url: &str, request_type: &str) -> bool {
        let req = match Request::new(url, source_url, request_type) {
            Ok(r) => r,
            Err(_) => return false,
        };
        let result = self.engine.borrow().check_network_request(&req);
        result.matched && result.exception.is_none()
    }

    /// Check if a domain should be blocked (for CONNECT tunnels).
    pub fn should_block_domain(&self, host_port: &str) -> bool {
        let host = host_port.split(':').next().unwrap_or(host_port);
        let url = format!("https://{}/", host);
        self.should_block(&url, &url, "other")
    }

    /// Download EasyList + EasyPrivacy, compile, and hot-swap the engine.
    pub async fn update_from_network(&self) -> anyhow::Result<()> {
        let client = reqwest::Client::builder().no_proxy().build()?;

        let easylist_url = "https://easylist.to/easylist/easylist.txt";
        let easyprivacy_url = "https://easylist.to/easylist/easyprivacy.txt";

        log::info!("Downloading EasyList...");
        let easylist = client.get(easylist_url).send().await?.text().await?;
        log::info!("Downloading EasyPrivacy...");
        let easyprivacy = client.get(easyprivacy_url).send().await?.text().await?;

        let mut filter_set = FilterSet::new(false);
        filter_set.add_filter_list(&easylist, ParseOptions::default());
        filter_set.add_filter_list(&easyprivacy, ParseOptions::default());

        let new_engine = Engine::from_filter_set(filter_set, true);

        let count = easylist.lines().chain(easyprivacy.lines())
            .filter(|l| !l.is_empty() && !l.starts_with('!') && !l.starts_with('['))
            .count() as u64;

        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        // Serialize to disk cache
        let cache_path = self.cache_dir.join("filter_lists");
        std::fs::create_dir_all(&cache_path)?;

        let dat_path = cache_path.join("engine.dat");
        let serialized = new_engine.serialize();
        std::fs::write(&dat_path, &serialized)?;

        let meta = FilterMeta { rule_count: count, last_updated: now };
        let meta_path = cache_path.join("engine.meta");
        std::fs::write(&meta_path, serde_json::to_string(&meta)?)?;

        // Hot-swap
        *self.engine.borrow_mut() = new_engine;
        *self.rule_count.borrow_mut() = count;
        *self.last_updated.borrow_mut() = now;

        log::info!("Adblock engine updated: {} rules", count);
        Ok(())
    }

    /// Get filter stats as JSON.
    pub fn get_stats(&self) -> FilterStats {
        FilterStats {
            rule_count: *self.rule_count.borrow(),
            last_updated: *self.last_updated.borrow(),
            enabled: true,
        }
    }
}

#[derive(serde::Serialize, serde::Deserialize)]
pub struct FilterMeta {
    pub rule_count: u64,
    pub last_updated: u64,
}

#[derive(serde::Serialize)]
pub struct FilterStats {
    pub rule_count: u64,
    pub last_updated: u64,
    pub enabled: bool,
}
