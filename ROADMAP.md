# LoonBox Roadmap

This is the public-facing roadmap for LoonBox development. Each phase builds on the previous one.

---

## Completed

### Phase 0: Foundation
Project setup, rebrand from internal name to LoonBox, AGPL-3.0 license with ecosystem carve-out, CI pipeline, repository structure.

### Phase 1: Audio Engine
Rust audio engine using Symphonia (decoder) and cpal (output). Gapless playback, sample-rate resampling, volume control, 10-band parametric EQ with 17 presets, real-time DSP pipeline. FFI bridge via flutter_rust_bridge.

### Phase 2: Library & Metadata
SQLite database via Drift with full track/album/artist schema. Folder scanning with file watcher for live updates. Metadata extraction via lofty (MP3, FLAC, OGG, WAV, AAC). Album art extraction and caching. MusicBrainz integration for track, album, and full library auto-tagging.

### Phase 3: Core UI
Complete desktop UI: library view with sortable columns, album grid with detail pages, artist browser, playlist management (CRUD + reorder), search, queue management with shuffle/repeat, now-playing bar and full-screen now-playing view, settings page with EQ controls, audio visualizers (spectrum, waveform, oscilloscope, VU meter), system tray with media controls, Windows SMTC integration, keyboard shortcuts, feather theming (5 built-in feathers), i18n support. Classic and modern shell layouts. Home page with recently played, jump back in, and discovery sections.

### Phase 3.5: Community Launch
Open-source release on GitHub. Documentation, contribution guidelines, issue templates. First public builds.

### Phase 10: Embedded Browser
WebView2 embedded browser with Rust filtering proxy, Brave adblock engine, domain allowlist/blocklist, JS bridge for trusted domains. Browser settings UI.

---

## In Progress

---

## Planned

### Phase 4: Feathers
Full theming system beyond color palettes. Feather shells — complete layout transformations (e.g., a Winamp-style 3-panel skin). Plumage UI for browsing and switching feathers. Fullscreen visualizer mode. User-uploadable visualizers via The Nest. Potential support for importing Winamp .wsz skins.

### Phase 5: Extensions
Lua extension system via mlua. Sandboxed execution with permission model. Extension manifest format. Calls (event hooks) for track changes, playback events, library updates. UI slot system for extensions to render into designated areas. First-party extensions: Last.fm scrobbler, lyrics display. The Nest marketplace for community extensions.

### Phase 6: Polish & Ship
Smart playlists with rule-based DSL. Cross-platform packaging and distribution (installers, app stores). Linux MPRIS integration. macOS media key support. Performance optimization for large libraries.

### Phase 7: Tremolo
Decentralized music distribution and purchase platform. BitTorrent-based delivery via rqbit. Discover page for browsing available music. Legal, artist-authorized content only.

### Phase 8: Subsonic Integration
Connect to Navidrome, Airsonic, Gonic, and other Subsonic-compatible servers. Stream or sync remote libraries. Token-based authentication.

### Phase 9: LoonBox Accounts & Social
User accounts for Tremolo purchases, The Nest downloads, and cloud sync. Follow artists and friends. Share playlists. Listening activity feed. Synced favorites, playlists, and settings across devices.

---

## Want to Help?

See [CONTRIBUTING.md](CONTRIBUTING.md) to get started. Check the [issues](https://github.com/mplsllc/LoonBox/issues) for tasks labeled `good first issue`.
