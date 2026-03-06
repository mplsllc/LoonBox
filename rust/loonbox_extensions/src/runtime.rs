//! Lua extension runtime — sandboxed Lua 5.4 via mlua.
//!
//! Each extension gets its own Lua state with:
//! - No file I/O (os, io, dofile, loadfile removed)
//! - No process execution (os.execute removed)
//! - API access gated by permissions

use std::collections::HashMap;
use std::path::Path;
use std::sync::{Arc, Mutex};

use mlua::prelude::*;

use crate::{ExtensionManifest, Permission};

/// A loaded, running extension instance.
pub struct ExtensionInstance {
    pub manifest: ExtensionManifest,
    pub permissions: Vec<Permission>,
    lua: Lua,
    storage: Arc<Mutex<HashMap<String, String>>>,
}

/// Events that extensions can hook into ("Calls" in LoonBox vocabulary).
#[derive(Debug, Clone)]
pub enum ExtensionCall {
    TrackChange {
        title: String,
        artist: String,
        album: String,
        file_path: String,
        duration_ms: u64,
    },
    PlaybackStart,
    PlaybackStop,
    TrackEnd {
        title: String,
        artist: String,
        album: String,
        duration_ms: u64,
        played_ms: u64,
    },
    LibraryScanComplete {
        total: u64,
    },
    AppStart,
    AppExit,
}

impl ExtensionCall {
    fn hook_name(&self) -> &'static str {
        match self {
            Self::TrackChange { .. } => "on_track_change",
            Self::PlaybackStart => "on_playback_start",
            Self::PlaybackStop => "on_playback_stop",
            Self::TrackEnd { .. } => "on_track_end",
            Self::LibraryScanComplete { .. } => "on_library_scan_complete",
            Self::AppStart => "on_app_start",
            Self::AppExit => "on_app_exit",
        }
    }
}

impl ExtensionInstance {
    /// Load an extension from its directory.
    pub fn load(dir: &Path) -> Result<Self, String> {
        // Read manifest
        let manifest_path = dir.join("extension.json");
        let manifest_str = std::fs::read_to_string(&manifest_path)
            .map_err(|e| format!("Failed to read extension.json: {}", e))?;
        let manifest: ExtensionManifest = serde_json::from_str(&manifest_str)
            .map_err(|e| format!("Invalid extension.json: {}", e))?;

        // Parse permissions
        let permissions: Vec<Permission> = manifest
            .permissions
            .iter()
            .filter_map(|s| Permission::parse(s))
            .collect();

        // Create sandboxed Lua state
        let lua = Lua::new();

        // Remove dangerous globals
        Self::sandbox(&lua)?;

        // Read and load the entry script
        let entry_path = dir.join(&manifest.entry);
        let script = std::fs::read_to_string(&entry_path)
            .map_err(|e| format!("Failed to read entry script '{}': {}", manifest.entry, e))?;

        let storage = Arc::new(Mutex::new(HashMap::new()));

        // Register the loonbox API table
        Self::register_api(&lua, &permissions, &manifest.id, storage.clone())?;

        // Execute the entry script
        lua.load(&script)
            .set_name(&manifest.entry)
            .exec()
            .map_err(|e| format!("Lua error in '{}': {}", manifest.entry, e))?;

        Ok(Self {
            manifest,
            permissions,
            lua,
            storage,
        })
    }

    /// Remove dangerous Lua standard library functions.
    fn sandbox(lua: &Lua) -> Result<(), String> {
        lua.load(
            r#"
            -- Remove file I/O
            io = nil
            -- Remove dangerous os functions, keep os.time and os.clock
            if os then
                local time = os.time
                local clock = os.clock
                local difftime = os.difftime
                os = { time = time, clock = clock, difftime = difftime }
            end
            -- Remove code loading from files
            dofile = nil
            loadfile = nil
            -- Remove debug library (can escape sandbox)
            debug = nil
            "#,
        )
        .exec()
        .map_err(|e| format!("Sandbox setup failed: {}", e))?;
        Ok(())
    }

    /// Register the `loonbox` API table in Lua.
    fn register_api(
        lua: &Lua,
        permissions: &[Permission],
        extension_id: &str,
        storage: Arc<Mutex<HashMap<String, String>>>,
    ) -> Result<(), String> {
        let loonbox = lua
            .create_table()
            .map_err(|e| format!("Failed to create loonbox table: {}", e))?;

        // loonbox.log(message)
        let ext_id = extension_id.to_string();
        let log_fn = lua
            .create_function(move |_, msg: String| {
                log::info!("[ext:{}] {}", ext_id, msg);
                Ok(())
            })
            .map_err(|e| format!("Failed to create log function: {}", e))?;
        loonbox
            .set("log", log_fn)
            .map_err(|e| format!("Failed to set log: {}", e))?;

        // Storage API (requires "storage" permission)
        if permissions.contains(&Permission::Storage) {
            let storage_table = lua
                .create_table()
                .map_err(|e| format!("Failed to create storage table: {}", e))?;

            let st = storage.clone();
            let get_fn = lua
                .create_function(move |_, key: String| {
                    let store = st.lock().unwrap();
                    Ok(store.get(&key).cloned())
                })
                .map_err(|e| format!("Failed to create storage.get: {}", e))?;

            let st = storage.clone();
            let set_fn = lua
                .create_function(move |_, (key, value): (String, String)| {
                    let mut store = st.lock().unwrap();
                    store.insert(key, value);
                    Ok(())
                })
                .map_err(|e| format!("Failed to create storage.set: {}", e))?;

            let st = storage.clone();
            let delete_fn = lua
                .create_function(move |_, key: String| {
                    let mut store = st.lock().unwrap();
                    store.remove(&key);
                    Ok(())
                })
                .map_err(|e| format!("Failed to create storage.delete: {}", e))?;

            storage_table
                .set("get", get_fn)
                .map_err(|e| format!("{}", e))?;
            storage_table
                .set("set", set_fn)
                .map_err(|e| format!("{}", e))?;
            storage_table
                .set("delete", delete_fn)
                .map_err(|e| format!("{}", e))?;

            loonbox
                .set("storage", storage_table)
                .map_err(|e| format!("{}", e))?;
        }

        // Player API stubs (requires player:read or player:control)
        let has_player_read = permissions.contains(&Permission::PlayerRead)
            || permissions.contains(&Permission::PlayerControl);
        if has_player_read {
            let player_table = lua
                .create_table()
                .map_err(|e| format!("Failed to create player table: {}", e))?;

            // These are stubs — actual implementation wires through FFI bridge
            let get_state = lua
                .create_function(|_, ()| Ok("stopped"))
                .map_err(|e| format!("{}", e))?;
            player_table
                .set("get_state", get_state)
                .map_err(|e| format!("{}", e))?;

            let get_track = lua
                .create_function(|lua, ()| {
                    let t = lua.create_table()?;
                    t.set("title", "")?;
                    t.set("artist", "")?;
                    t.set("album", "")?;
                    Ok(t)
                })
                .map_err(|e| format!("{}", e))?;
            player_table
                .set("get_current_track", get_track)
                .map_err(|e| format!("{}", e))?;

            if permissions.contains(&Permission::PlayerControl) {
                for cmd in &["play", "pause", "stop", "next", "previous"] {
                    let noop = lua
                        .create_function(|_, ()| Ok(()))
                        .map_err(|e| format!("{}", e))?;
                    player_table
                        .set(*cmd, noop)
                        .map_err(|e| format!("{}", e))?;
                }

                let seek = lua
                    .create_function(|_, _pos: u64| Ok(()))
                    .map_err(|e| format!("{}", e))?;
                player_table
                    .set("seek", seek)
                    .map_err(|e| format!("{}", e))?;
            }

            loonbox
                .set("player", player_table)
                .map_err(|e| format!("{}", e))?;
        }

        // Network API stubs (requires network permission)
        let has_network = permissions.contains(&Permission::NetworkAll)
            || permissions.iter().any(|p| matches!(p, Permission::NetworkDomain(_)));
        if has_network {
            let net_table = lua
                .create_table()
                .map_err(|e| format!("Failed to create net table: {}", e))?;

            // Stub — actual implementation will use reqwest or ureq
            let get_fn = lua
                .create_function(|_, _url: String| -> LuaResult<String> {
                    Ok(String::new())
                })
                .map_err(|e| format!("{}", e))?;
            net_table
                .set("get", get_fn)
                .map_err(|e| format!("{}", e))?;

            let post_fn = lua
                .create_function(|_, (_url, _body): (String, String)| -> LuaResult<String> {
                    Ok(String::new())
                })
                .map_err(|e| format!("{}", e))?;
            net_table
                .set("post", post_fn)
                .map_err(|e| format!("{}", e))?;

            loonbox
                .set("net", net_table)
                .map_err(|e| format!("{}", e))?;
        }

        lua.globals()
            .set("loonbox", loonbox)
            .map_err(|e| format!("Failed to set loonbox global: {}", e))?;

        Ok(())
    }

    /// Dispatch a Call (event hook) to this extension.
    pub fn dispatch_call(&self, call: &ExtensionCall) -> Result<Option<String>, String> {
        let hook_name = call.hook_name();

        // Check if the extension registered this hook
        if let Some(ref hooks) = self.manifest.hooks {
            if !hooks.contains(&hook_name.to_string()) {
                return Ok(None);
            }
        }

        // Look for the global function
        let globals = self.lua.globals();
        let func: LuaFunction = match globals.get(hook_name) {
            Ok(f) => f,
            Err(_) => return Ok(None), // Function not defined, skip
        };

        // Build the argument table
        let arg = self.call_to_lua_table(call)?;

        // Call the function
        let result: LuaResult<Option<String>> = func.call(arg);
        match result {
            Ok(val) => Ok(val),
            Err(e) => {
                log::warn!(
                    "[ext:{}] Error in hook '{}': {}",
                    self.manifest.id,
                    hook_name,
                    e
                );
                Err(format!("Hook '{}' error: {}", hook_name, e))
            }
        }
    }

    /// Call a named Lua function (for UI slot callbacks).
    pub fn call_function(&self, name: &str, args_json: &str) -> Result<String, String> {
        let globals = self.lua.globals();
        let func: LuaFunction = globals
            .get(name)
            .map_err(|_| format!("Function '{}' not found", name))?;

        // Parse JSON args into a Lua value via serde
        let json_value: serde_json::Value = serde_json::from_str(args_json)
            .map_err(|e| format!("Invalid JSON args: {}", e))?;
        let arg: LuaValue = self
            .lua
            .to_value(&json_value)
            .map_err(|e| format!("Failed to convert to Lua: {}", e))?;

        let result: String = func
            .call(arg)
            .map_err(|e| format!("Function '{}' error: {}", name, e))?;
        Ok(result)
    }

    /// Get the extension's in-memory storage (for persisting to DB on shutdown).
    pub fn get_storage(&self) -> HashMap<String, String> {
        self.storage.lock().unwrap().clone()
    }

    /// Restore storage from DB on load.
    pub fn set_storage(&self, data: HashMap<String, String>) {
        let mut store = self.storage.lock().unwrap();
        *store = data;
    }

    fn call_to_lua_table(&self, call: &ExtensionCall) -> Result<LuaValue, String> {
        let lua = &self.lua;
        let table = lua.create_table().map_err(|e| format!("{}", e))?;

        match call {
            ExtensionCall::TrackChange {
                title,
                artist,
                album,
                file_path,
                duration_ms,
            } => {
                table.set("title", title.as_str()).map_err(|e| format!("{}", e))?;
                table.set("artist", artist.as_str()).map_err(|e| format!("{}", e))?;
                table.set("album", album.as_str()).map_err(|e| format!("{}", e))?;
                table.set("file_path", file_path.as_str()).map_err(|e| format!("{}", e))?;
                table.set("duration_ms", *duration_ms).map_err(|e| format!("{}", e))?;
            }
            ExtensionCall::TrackEnd {
                title,
                artist,
                album,
                duration_ms,
                played_ms,
            } => {
                table.set("title", title.as_str()).map_err(|e| format!("{}", e))?;
                table.set("artist", artist.as_str()).map_err(|e| format!("{}", e))?;
                table.set("album", album.as_str()).map_err(|e| format!("{}", e))?;
                table.set("duration_ms", *duration_ms).map_err(|e| format!("{}", e))?;
                table.set("played_ms", *played_ms).map_err(|e| format!("{}", e))?;
            }
            ExtensionCall::LibraryScanComplete { total } => {
                table.set("total", *total).map_err(|e| format!("{}", e))?;
            }
            _ => {} // No args for simple events
        }

        Ok(LuaValue::Table(table))
    }
}
