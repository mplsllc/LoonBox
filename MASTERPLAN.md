# LoonBox — Master Plan

Internal development roadmap. Tracks every phase, sub-task, and decision. For the public-facing version, see `ROADMAP.md`.

**Product:** LoonBox — cross-platform desktop music player, spiritual successor to Songbird/Nightingale
**Stack:** Flutter + Rust (via flutter_rust_bridge), Drift/SQLite, Riverpod
**Org:** MPLS LLC (mp.ls) — loonbox.app
**License:** AGPL-3.0 (source), CLA (contributors), ecosystem carve-out (feathers/extensions any license)

---

## Naming Vocabulary

| Term | Meaning | Usage |
|------|---------|-------|
| **Feathers** | Themes / skins | Always — core identity |
| **The Nest** | Extension/feather marketplace | Future, name-reserved, manifest fields designed in |
| **Calls** | Event hooks dispatched to extensions | In extension API and docs |
| **Plumage** | In-app feather preview/switcher | In feather settings UI |
| **Flock** | Community / contributors | In docs, README, community messaging |
| **Tremolo** | Decentralized music distribution + purchase platform | In Discover page, settings, marketing |

Don't force vocabulary where plain language is clearer (e.g., "scan" not "Diving").

---

## Phase 0: Project Hygiene + Rebrand — COMPLETE

- [x] 0.1 — Rebrand all Dart classes, Rust crates, directories, package names, UI strings from "Loon" to "LoonBox"
- [x] 0.2 — Initial commit + tag (v0.0.0-scaffold)
- [x] 0.3 — CI pipeline (GitHub Actions: Windows, Linux, macOS)
- [x] 0.4 — License + community files (AGPL-3.0, CLA, CONTRIBUTING.md, issue templates)
- [x] 0.5 — Build docs (BUILDING.md)
- [x] 0.6 — Linting (rustfmt, clippy, analysis_options.yaml)

---

## Phase 1: Audio Engine — COMPLETE

- [x] 1.1 — Decoder thread (Symphonia → f32 PCM, MP3/FLAC/OGG/WAV/AAC)
- [x] 1.2 — Output thread (cpal, ring buffer, rubato resampling)
- [x] 1.3 — Control thread (play/pause/stop/seek/next/previous, position tracking)
- [x] 1.4 — FFI bridge wiring (player_load, player_play, player_pause, player_stop, player_seek, etc.)
- [x] 1.5 — Gapless playback foundation (pre-load next track, seamless switch)
- [x] 1.6 — Error handling (corrupt files, missing files, device changes)

---

## Phase 2: Library Scanning + Database — COMPLETE

- [x] 2.1 — DB migration scaffolding (Drift versioned migrations)
- [x] 2.2 — Watch directory registration (folder picker → watch_directories table → trigger scan)
- [x] 2.3 — Rust scanner (recursive walk, filter by audio extensions, batch metadata extraction via lofty)
- [x] 2.4 — DB insertion pipeline (upsert tracks, create/update artists and albums)
- [x] 2.5 — Album art extraction (embedded art → disk cache, fallback folder.jpg/cover.png)
- [x] 2.6 — File watcher (Rust notify crate, incremental re-scan on add/remove/modify)
- [x] 2.7 — Rescan + clean (re-probe all files, remove entries for missing files)

---

## Phase 3: Core UI — COMPLETE

- [x] 3.1 — i18n setup + app shell (flutter_localizations, intl, ARB files, sidebar navigation)
- [x] 3.2 — Library list view (sortable columns, click to play, right-click context menus, renamed to "Songs")
- [x] 3.3 — Now-playing bar (album art, title, artist, play/pause, next/prev, seek, volume)
- [x] 3.4 — Now-playing full view (large album art, up-next queue, lyrics area)
- [x] 3.5 — Album view (grid with art, detail page with track list, sort by name/artist/year/date)
- [x] 3.6 — Artist view (artist list → detail page with albums + tracks)
- [x] 3.7 — Queue management (play next/later, drag reorder, clear, shuffle, repeat modes)
- [x] 3.8 — Settings screen (audio output, library paths, rescan, about, EQ controls)
- [x] 3.9 — Search (global across tracks/albums/artists, fuzzy matching, grouped results)

### Additional Phase 3 work (completed after initial milestone)

- [x] 3.10 — Home hub page (listening insights, recently played, top albums, jump back in, recently added, discover suggestions, onboarding view, coming soon cards for Tremolo/Nest)
- [x] 3.11 — Play tracking (play counts per track/album, last played timestamps, skip counts)
- [x] 3.12 — Audio visualizers (spectrum bars, waveform, oscilloscope, VU meter — ~30fps, real-time FFT from Rust)
- [x] 3.13 — MusicBrainz auto-tagging (album-level matching with confidence scoring, batch workflow with progress banner, per-track lookup dialog)
- [x] 3.14 — Custom window chrome (32px title bar, DragToMoveArea, Windows 11 caption buttons, hidden system title bar)
- [x] 3.15 — Interactivity pass (right-click context menus on all cards, clickable artist/album links throughout, artists page redesign with album art avatars and album thumbnails)
- [x] 3.16 — Feather theming foundation (4 built-in feathers: Blue Monday, Purple Rain, Pink Martini, Gonzo — ColorScheme-based, runtime switching via Riverpod)
- [x] 3.17 — System tray (minimize to tray, tray icon with playback controls)
- [x] 3.18 — Windows SMTC integration (media key support)
- [x] 3.19 — Keyboard shortcuts (global hotkeys for playback)

---

## Phase 3.5: Community Launch — NOT STARTED

- [ ] README polished with screenshots of the working app
- [ ] 60-90 second demo video (scan folder → browse → play → queue → show on multiple platforms)
- [ ] CONTRIBUTING.md and BUILDING.md verified (clone → build in 5 minutes)
- [ ] 3-5 "good first issue" tickets filed
- [ ] Announcement posts: Nightingale community, r/linux, r/audiophile, r/opensource, Hacker News (Show HN)
- [ ] Messaging: lead with heritage ("Spiritual successor to Songbird/Nightingale"), demo video + screenshots, honest about alpha status, "The Flock is forming"

---

## Phase 4: Feathers (Theming System) — NOT STARTED

Currently have 4 color-palette feathers. This phase adds the full system.

- [ ] 4.1 — Feather manifest spec (JSON with Nest-ready fields: id, name, version, author, colors, fonts, spacing, screenshots, pricing_tier, etc.)
- [ ] 4.2 — Feather loader (dynamic loading from ~/.loonbox/feathers/, replace static map)
- [ ] 4.3 — ThemeData builder (manifest → full Flutter ThemeData)
- [ ] 4.4 — Upgrade built-in feathers (real personality: backgrounds, fonts, density)
- [ ] 4.5 — Hot-swap feathers (runtime switch with animated transition)
- [ ] 4.6 — Background image system (feather-specified image + blend mode + opacity)
- [ ] 4.7 — Plumage (in-app feather preview/switcher, live preview, side-by-side comparison)
- [ ] 4.8 — Feather creator guide (docs: manifest format, template to fork)
- [ ] 4.9 — Feather installation UX (drag-and-drop .loonfeather, settings list with Plumage previews)

### Feather shells (design idea — not yet approved for implementation)

Two tiers: light feathers (colors/fonts only) vs full feathers (complete shell replacement).
- Example: "LLAMA" feather transforms LoonBox into a Winamp replica (3-panel, beveled buttons, LED display)
- Classic shell already exists as separate layout (`classic_shell_layout.dart`)
- Potential .wsz Winamp skin import support

---

## Phase 5: Extensions (Lua Plugin System) — NOT STARTED

- [ ] 5.1 — Extension UI slot system design spec (enumerate all injection points: context menus, toolbar, sidebar tabs, now-playing panels, status bar)
- [ ] 5.2 — Lua runtime integration (mlua, sandboxed Lua 5.4 per extension, dedicated thread pool)
- [ ] 5.3 — Extension manifest spec (JSON with Nest-ready fields: id, name, version, permissions, hooks, ui_slot_declarations, etc.)
- [ ] 5.4 — Permission model implementation (user approval on install, runtime enforcement)
- [ ] 5.5 — UI slot implementation (extensions register via manifest, Flutter renders extension data into slots)
- [ ] 5.6 — Player API for Lua (loonbox.player.play/pause/stop/next/seek/get_state/get_current_track)
- [ ] 5.7 — Library API for Lua (loonbox.library.search/get_track/get_album/get_artist/update_metadata)
- [ ] 5.8 — Network API for Lua (loonbox.net.get/post — sandboxed, rate limited, requires permission)
- [ ] 5.9 — Calls (event hooks: on_track_change, on_playback_start/stop, on_track_end, on_library_scan_complete, on_app_start/exit)
- [ ] 5.10 — Storage API for Lua (loonbox.storage.get/set/delete — backed by extension_storage table)
- [ ] 5.11 — First-party extensions (Last.fm scrobbler, lyrics display, play counter)
- [ ] 5.12 — Extension manager UI (list installed, enable/disable, permissions, uninstall, install from .loonext)
- [ ] 5.13 — Extension developer guide (API reference, tutorial, manifest spec, example extensions)

---

## Phase 6: Polish + Ship — PARTIAL

Some items pulled forward into Phase 3.

- [x] 6.1 — EQ implementation (Rust biquad filters, 17 presets, visual EQ curve in UI)
- [ ] 6.2 — Smart playlists (SmartRule → Drift queries, auto-update on library changes)
- [x] 6.3 — Keyboard shortcuts + media keys (Windows SMTC done; Linux MPRIS and macOS MediaSession pending)
- [x] 6.4 — System tray (minimize to tray, tray icon with playback controls)
- [ ] 6.5 — Notifications (track change via native OS notification APIs)
- [ ] 6.6 — Crash reporting (Sentry, Rust panic capture, opt-in, privacy-respecting)
- [ ] 6.7 — DB migration verification (integration test: create v1, bump to v2, verify data survives)
- [ ] 6.8 — Distribution pipeline (GitHub Actions release on tag → Windows Inno Setup .exe, macOS .dmg, Linux Flatpak + AppImage, Android APK)
- [ ] 6.9 — First-run experience (welcome → pick folder → scan with progress → show library → offer feather selection)
- [ ] 6.10 — README + landing page (screenshots, feature list, download links, GitHub Pages)

### Remaining Phase 6 items for v0.1.0:
- 6.2 Smart playlists
- 6.3 Linux MPRIS + macOS media keys (Windows done)
- 6.5 Notifications
- 6.6 Crash reporting
- 6.7 DB migration verification
- 6.8 Distribution pipeline
- 6.9 First-run experience
- 6.10 README + landing page

---

## Phase 7: Tremolo — NOT STARTED (post v0.1.0)

Decentralized music distribution + purchase platform. Formerly "Artist Direct".

### Architecture decisions:
- **Tokio coexistence:** loonbox_torrent encapsulates Tokio privately. Synchronous crossbeam-channel APIs to bridge layer. Tokio must NOT touch audio thread or share thread pools with cpal.
- **Legal sources:** First-party Dart code, NOT Lua extensions (need rich UI beyond what extension slots support). Factor into Lua later.
- **Web service:** Artist portal, Stripe payments, release management — separate codebase/repo.
- **streaming_accounts NOT repurposed** for torrent state. Keep for Phase 8 (Subsonic).

### Sub-phases:
- [ ] 7.1 — loonbox_torrent crate (rqbit wrapper, TorrentEngine API, state persistence, seeding, file filtering)
- [ ] 7.2 — Settings and trust model (Artist Direct toggle, download location, speed limits, external torrent toggle with warning, trust tiers: Official/Community/External)
- [ ] 7.3 — Built-in legal sources (Internet Archive, Etree, Jamendo — shippable independently, Discover page with tabs)
- [ ] 7.4 — Tremolo store (web service: artist registration, Stripe Connect, pricing, release management; app: Artist profiles, purchase flow, "Owned" badge, tip button)
- [ ] 7.5 — Purchase funnel (lossless FLAC on official, zero-step library integration, matched-release prompts, no degradation of external content)
- [ ] 7.6 — Artist seeding and fan distribution (auto-seed purchased, fan CDN, seeding stats, artist dashboard, pre-release seeding, seed health monitoring)

### DB additions:
- `purchases` table (releaseId, artistId, amount, currency, stripePaymentId, purchasedAt, receiptJson)
- `torrent_sources` table (infohash PK, source, sourceUrl, artistId, releaseId, trustTier, addedAt)
- Existing `tracks.source` / `tracks.sourceId` used for 'artist_direct' / 'community' / 'torrent'

---

## Phase 8: Subsonic Integration — NOT STARTED (post v0.1.0)

Connect to Navidrome, Airsonic, Gonic, and other Subsonic-compatible servers.

### Architecture decisions:
- **streaming_accounts table** used for server credentials
- **Token auth** (MD5 + salt), API v1.16.1
- **Temp-download-then-play** initially (true streaming later)

### Sub-phases:
- [ ] 8.1 — Subsonic client (Dart HTTP client, token auth, API v1.16.1)
- [ ] 8.2 — Server account management (add/edit/remove servers in settings, connection testing)
- [ ] 8.3 — Remote library browsing (albums, artists, playlists from server)
- [ ] 8.4 — Playback integration (download track → play via existing audio engine)
- [ ] 8.5 — Offline sync (pin albums/playlists for offline, background download)

---

## Phase 9: LoonBox Accounts & Social — NOT STARTED (post v0.1.0)

User accounts for Tremolo purchases, The Nest downloads, and cloud sync.

### Sub-phases:
- [ ] 9.1 — User authentication (login/register, session management)
- [ ] 9.2 — Tremolo/Nest purchase history (link to account)
- [ ] 9.3 — Follow artists and friends
- [ ] 9.4 — Playlist sharing
- [ ] 9.5 — Listening activity feed
- [ ] 9.6 — Cloud sync (favorites, playlists, settings across devices)

---

## Phase 10: Embedded Browser — IN PROGRESS

Purpose-built, two-mode embedded browser. Not Songbird's fatal flaw (shipping a full browser engine) — this is a focused, sandboxed browser with a Rust filtering proxy. Trusted mode for first-party content (The Nest, Tremolo) with JS-to-player bridge. Linked content mode for external URLs with ad blocking, tracking protection, and sandboxing.

### Architecture:
- **WebView2** via `webview_flutter_windows` — platform webview, not bundled engine
- **Rust filtering proxy** (`loonbox_browser` crate) — axum + Brave `adblock` crate, all traffic routed through localhost proxy
- **Two modes:** Trusted (no chrome, JS bridge active, for `*.loonbox.app` / `*.tremolo.app`) and Linked Content (address bar + back button, sandboxed, no bridge, for external URLs)
- **Overlay panel** — slides in from right at 65% width, main content still visible and interactive behind it
- **Tokio coexistence:** Same pattern as loonbox_torrent — private Tokio runtime, never touches audio thread

### Rust crate: `loonbox_browser`
Dependencies: axum, hyper, reqwest (rustls-tls), adblock (Brave engine, MIT), tokio, serde, sha2, hex

FFI surface:
- `browser_start_proxy(port) / browser_stop_proxy() / browser_get_proxy_port()`
- `browser_update_filter_lists(lists)`
- `browser_verify_package(path, signature) -> bool`
- `browser_handle_js_message(payload) -> String`

### Sub-phases:
- [ ] 10.1 — loonbox_browser crate skeleton (compile clean, FFI stubs in bridge)
- [ ] 10.2 — Filtering proxy (axum on 127.0.0.1:{dynamic_port}, trusted passthrough vs external filtering pipeline)
- [ ] 10.3 — adblock integration (load EasyList/EasyPrivacy, block matching requests, strip tracking params)
- [ ] 10.4 — Flutter BrowserPane (WebView2 widget, trusted mode, proxy routing)
- [ ] 10.5 — JS bridge (player.play, player.pause, player.getState, nest.installFeather, nest.installExtension, tremolo.purchase, app.navigate — whitelist-only)
- [ ] 10.6 — Linked content mode (address bar + back button, mode switching on navigation, shield icon with blocked count)
- [ ] 10.7 — Browser overlay panel (AnimatedPositioned slide-in, 65% width, close/expand, main content visible behind)
- [ ] 10.8 — Package signature verification (SHA-256 hash + MPLS LLC signed manifest, confirmation dialog with permissions)
- [ ] 10.9 — Filter list management UI (bundled EasyList/EasyPrivacy, community lists from The Nest, custom import, update all)
- [ ] 10.10 — Browser settings page (filter lists, privacy toggles, trusted domains list)

### New files:
| File | Purpose |
|------|---------|
| `rust/loonbox_browser/src/lib.rs` | Crate root |
| `rust/loonbox_browser/src/proxy.rs` | axum filtering proxy |
| `rust/loonbox_browser/src/filter_lists.rs` | adblock engine + list management |
| `rust/loonbox_browser/src/js_bridge.rs` | Trusted mode message handler |
| `rust/loonbox_browser/src/signatures.rs` | Package verification |
| `lib/features/browser/browser_pane.dart` | WebView2 widget, mode switching |
| `lib/features/browser/browser_chrome.dart` | Address bar + controls (linked content mode) |
| `lib/features/browser/browser_overlay.dart` | Slide-in overlay panel |
| `lib/features/browser/browser_provider.dart` | Browser state (Riverpod) |
| `lib/features/browser/blocked_requests_sheet.dart` | Blocked requests viewer |
| `lib/features/browser/filter_list_settings.dart` | Filter list management |
| `lib/features/browser/browser_settings_page.dart` | Browser settings |

### Integration points:
- Tremolo (Phase 7): Tremolo store pages render in trusted mode, play buttons queue tracks via JS bridge
- The Nest: Feather/extension browsing in trusted mode, install triggers go through signature verification
- Artist profiles: External links (Wikipedia, social media) open in linked content mode
- Filter lists distributed via The Nest as another package type (BitTorrent delivery)

---

## Out of Scope for v0.1.0

- iOS (hardest app store, add later)
- The Nest marketplace (name reserved, manifest fields designed in, built post-v1)
- LoonBox Pro (premium tier bundled with The Nest, post-v1)
- Plumage standalone tool (in-app preview is v0.1.0, standalone creator is post-v1)
- Streaming service integration (streaming_accounts table ready, complex auth/legal, post-v1)
- WASM extension runtime (Lua is v1, WASM is v2)
- WMA/APE/DSD/AIFF (Symphonia doesn't support; MP3/FLAC/OGG/WAV/AAC covers 99%)
- Winamp skin import / LLAMA feather (design idea, not approved)

---

## Critical Path to v0.1.0

```
Phase 0 ✓ → Phase 1 ✓ → Phase 2 ✓ → Phase 3 ✓ → Phase 6 (remaining) → Phase 3.5 (launch)
                                                  ↘ Phase 4 (Feathers) — can parallelize
                                                  ↘ Phase 5 (Extensions) — can parallelize after Phase 3
                                                  ↘ Phase 10 (Browser) ← ACTIVE — feeds into Phase 7 (Tremolo)
```

Phase 10 (Browser) is active now. It provides the runtime for The Nest and Tremolo — builds the bridge between the player and the web services before those services exist.
Phases 4 and 5 can be worked in parallel after Phase 3. Phase 6 items are the minimum bar for a shippable release.
Phases 7, 8, 9 are post v0.1.0.

---

## Feature Ideas (Backlog)

- **Floating mini player** — compact always-on-top window (like Spotify mini mode / PiP), alternative to NowPlayingBar
- **Fullscreen visualizer mode** — dedicated visualizer view, community-uploaded visualizers via The Nest
