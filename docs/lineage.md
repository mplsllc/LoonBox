# LoonBox Lineage: Songbird → Nightingale → LoonBox

LoonBox is the spiritual successor to [Songbird](https://en.wikipedia.org/wiki/Songbird_(software)) (2006–2010, POTI Inc.) and its community fork [Nightingale](http://getnightingale.com/) (2012–2018). While LoonBox is a ground-up rewrite — Songbird/Nightingale were XULRunner/Gecko/C++ applications, LoonBox is Flutter + Rust — the architectural DNA of those projects is embedded throughout LoonBox's design.

This document traces each piece of inherited design, mapping old source files to their modern equivalents.

---

## 1. Feathers (Theming System)

### Heritage

Songbird coined "feathers" for its theme system. A feather was a skin + layout combination, registered via RDF manifest and managed by `sbIFeathersManager`. The default was **Blue Monday**.

**Old source:** `feathers/bluemonday/install.rdf.in`
```xml
<songbird:skin>
  <Description>
    <songbird:name>Blue Monday</songbird:name>
    <songbird:internalName>bluemonday</songbird:internalName>
    <songbird:compatibleLayout>
      <Description>
        <songbird:layoutURL>chrome://bluemonday/content/xul/mainplayer.xul</songbird:layoutURL>
        <songbird:showChrome>true</songbird:showChrome>
      </Description>
    </songbird:compatibleLayout>
  </Description>
</songbird:skin>
```

**Old source:** `app/content/bindings/feathers.xml` — `sbIFeathersManager` binding with `switchFeathers()`, `currentSkinName`, `getSkinDescriptions()`, `getLayoutsForSkin()`.

### LoonBox equivalent

| Old concept | New implementation |
|---|---|
| `install.rdf` skin manifest | `feather.json` manifest (Phase 4.1) |
| `songbird:internalName` | `LoonBoxFeather.id` |
| `songbird:name` | `LoonBoxFeather.name` |
| `sbIFeathersManager.switchFeathers()` | `LoonBoxThemeNotifier.setFeather()` |
| `sbIFeathersManager.getSkinDescriptions()` | `FeatherEngine` registry (dynamic loader, Phase 4.2) |
| `songbird:compatibleLayout` (main + mini) | Future: responsive layouts per feather |
| CSS theme files | Flutter `ThemeData` built from feather manifest |
| Blue Monday default | Blue Monday default (`lib/theme/default_feathers/bluemonday.dart`) |

**Files:**
- Old: `feathers/bluemonday/`, `app/content/bindings/feathers.xml`
- New: `lib/theme/loonbox_theme.dart`, `lib/theme/feather_engine.dart`, `lib/theme/default_feathers/`

---

## 2. Extension System

### Heritage

Songbird extensions used Mozilla's addon model (XPI packages, `install.rdf` manifests, XPCOM component registration). Extensions could register display panes, overlay XUL, and interact with the library through XPCOM interfaces.

**Old source:** `extensions/mashTape/install.rdf.in`
```xml
<songbird:displayPane>
  <Description>
    <songbird:contentUrl>chrome://mashtape/content/mashTape.xul</songbird:contentUrl>
    <songbird:contentTitle>@EXTENSION_NAME@</songbird:contentTitle>
    <songbird:contentIcon>chrome://mashtape/content/mT_favicon.png</songbird:contentIcon>
    <songbird:defaultWidth>177</songbird:defaultWidth>
    <songbird:defaultHeight>177</songbird:defaultHeight>
    <songbird:suggestedContentGroups>contentpane</songbird:suggestedContentGroups>
    <songbird:showOnInstall>true</songbird:showOnInstall>
  </Description>
</songbird:displayPane>
```

### LoonBox equivalent

| Old concept | New implementation |
|---|---|
| `install.rdf` (RDF/XML) | `manifest.json` (Phase 5.3) |
| `em:id` (UUID) | `id` field in manifest |
| `em:targetApplication` + min/maxVersion | `min_loonbox_version` |
| `songbird:displayPane` | UI slot declarations (Phase 5.1) |
| `suggestedContentGroups` | Slot names: `contentpane`, `sidebar`, `toolbar`, etc. |
| `showOnInstall` | Slot visibility flags |
| XPCOM contractID registration | Lua module registration + permission model |
| XPI package format | `.loonext` zip format |
| `em:contributor` (translators) | `contributors` array in manifest |
| `em:localized` descriptions | i18n in manifest (per-locale name/description) |

**Files:**
- Old: `extensions/*/install.rdf.in`
- New: `rust/loonbox_extensions/src/lib.rs` (manifest model), `lib/services/extension_service.dart`

---

## 3. mashTape (Provider Architecture)

### Heritage

mashTape was Songbird's iconic extension — a content pane that aggregated artist info, photos, reviews, and news from multiple web sources. Its architecture was a typed provider plugin system.

**Old source:** `extensions/mashTape/components/public/ImashTape.idl`
```idl
interface sbIMashTapeProvider : nsISupports {
  readonly attribute string providerName;
  readonly attribute string providerType;
  void query(in AUTF8String searchTerms, in sbIMashTapeCallback updateFn);
};

interface sbIMashTapeInfoProvider : sbIMashTapeProvider {
  readonly attribute long numSections;
  readonly attribute string providerIconBio;
  readonly attribute string providerIconTags;
  readonly attribute string providerIconDiscography;
  readonly attribute string providerIconMembers;
  readonly attribute string providerIconLinks;
};

interface sbIMashTapePhotoProvider   : sbIMashTapeProvider { ... };
interface sbIMashTapeReviewProvider  : sbIMashTapeProvider {
  void queryFull(in AUTF8String artist, in AUTF8String album,
                 in AUTF8String track, in sbIMashTapeCallback updateFn);
};
interface sbIMashTapeRSSProvider     : sbIMashTapeProvider { ... };

interface sbIMashTapeManager : nsISupports {
  void addListener(in sbIMashTapeListener aListener);
  void removeListener(in sbIMashTapeListener aListener);
  void updateInfo(in AUTF8String section, in AUTF8String data);
};
```

### LoonBox equivalent

The mashTape provider pattern directly informs LoonBox's extension UI slot system (Phase 5.1) and Lua API design:

| Old concept | New implementation |
|---|---|
| `sbIMashTapeProvider.query()` | Lua `loonbox.net.get()` + `on_track_change` Call |
| Provider types (Info, Photo, Review, RSS) | Extension UI slot types |
| `sbIMashTapeManager.addListener()` | Calls (event hooks): `on_track_change`, etc. |
| `sbIMashTapeInfoProvider` sections (bio, tags, discography) | Now-playing panel slots |
| Multiple providers per type | Multiple extensions can register for same slot |
| `sbIMashTapeCallback` | Lua callback functions |
| mashTape as first-party extension | Lyrics + Scrobbler as first-party extensions (Phase 5.11) |

The mashTape model proves that a plugin-based content aggregation system works for music players. LoonBox's extension slot system is the modern version of this same idea.

**Files:**
- Old: `extensions/mashTape/`
- New: Phase 5.1 spec (`docs/extension-ui-slots.md`, planned)

---

## 4. Library Database Schema

### Heritage

Songbird used SQLite with an EAV (Entity-Attribute-Value) pattern for metadata flexibility. The `media_items` table held core item data, while `resource_properties` stored all metadata as property/value pairs keyed by URI-namespaced property names.

**Old source:** `components/library/localdatabase/content/schema.sql`
```sql
create table media_items (
  media_item_id integer primary key autoincrement,
  guid text unique not null,
  created integer not null,
  updated integer not null,
  content_url text not null,
  content_mime_type text,
  content_length integer,
  hidden integer not null check(hidden in (0, 1)),
  media_list_type_id integer,
  is_list integer not null check(is_list in (0, 1)) default 0,
  metadata_hash_identity text
);

create table properties (
  property_id integer primary key autoincrement,
  property_name text not null unique  -- URI namespace, e.g. 'http://songbirdnest.com/data/1.0#trackName'
);

create table resource_properties (
  media_item_id integer not null,
  property_id integer not null,
  obj text not null,
  obj_searchable text,
  obj_sortable text collate library_collate,
  primary key (media_item_id, property_id)
);
```

Property namespace: `http://songbirdnest.com/data/1.0#trackName`, `#albumName`, `#artistName`, `#duration`, `#genre`, `#trackNumber`, `#year`, `#discNumber`, `#lastPlayTime`, `#playCount`.

### LoonBox equivalent

LoonBox uses a denormalized schema (direct columns instead of EAV) for simplicity and type safety, but preserves the same metadata surface:

| Old property URI | New column |
|---|---|
| `data/1.0#trackName` | `tracks.title` |
| `data/1.0#albumName` | `tracks.album` |
| `data/1.0#artistName` | `tracks.artist` |
| `data/1.0#duration` | `tracks.duration_ms` |
| `data/1.0#genre` | `tracks.genre` |
| `data/1.0#trackNumber` | `tracks.track_number` |
| `data/1.0#year` | `tracks.year` |
| `data/1.0#discNumber` | `tracks.disc_number` |
| `data/1.0#lastPlayTime` | `tracks.last_played_at` |
| `data/1.0#playCount` | `tracks.play_count` |
| `media_items.content_url` | `tracks.file_path` |
| `media_items.content_length` | `tracks.file_size` |
| `media_items.content_mime_type` | `tracks.codec` |
| `media_items.hidden` | (not needed — no browser integration) |
| `media_items.is_list` | Separate `playlists` table |
| `simple_media_lists` | `playlist_tracks` table |
| `resource_properties_fts_all` | Drift full-text search (Phase 3.9) |

LoonBox extends the old schema with fields Songbird didn't have: `replay_gain_track`, `replay_gain_album`, `bpm`, `loudness_lufs`, `musicbrainz_track_id`, `bit_depth`, `sample_rate`, `loved`, `skip_count`.

The old `ANALYZE` stats showed optimization for ~10,000 track libraries. LoonBox's Drift queries will similarly be optimized for real-world library sizes.

**Files:**
- Old: `components/library/localdatabase/content/schema.sql`
- New: `lib/database/tables/tracks.dart`, `lib/database/tables/albums.dart`, `lib/database/tables/artists.dart`, `lib/database/database.dart`

---

## 5. Smart Playlist Constraint DSL

### Heritage

Songbird's smart playlists used `sbILibraryConstraintBuilder` — a fluent interface for building property/value filter groups that could be intersected.

**Old source:** `components/library/base/public/sbILibraryConstraints.idl`
```idl
interface sbILibraryConstraintBuilder : nsISupports {
  sbILibraryConstraintBuilder include(in AString aProperty, in AString aValue);
  sbILibraryConstraintBuilder includeList(in AString aProperty, in nsIStringEnumerator aValues);
  sbILibraryConstraintBuilder intersect();  // AND between groups
  sbILibraryConstraint get();               // compile the constraint
  sbILibraryConstraintBuilder parseFromString(in AString aSerialized);
};

interface sbILibraryConstraint : nsISupports {
  readonly attribute unsigned long groupCount;
  sbILibraryConstraintGroup getGroup(in unsigned long aIndex);
  AString toString();  // serialize for storage
};

interface sbILibraryConstraintGroup : nsISupports {
  readonly attribute nsIStringEnumerator properties;
  nsIStringEnumerator getValues(in AString aProperty);
};
```

### LoonBox equivalent

| Old concept | New implementation |
|---|---|
| `sbILibraryConstraintBuilder` | `SmartRule` + `SmartPlaylist` domain model |
| `.include(property, value)` | `SmartRule(field: RuleField.artist, operator: isEqualTo, value: "...")` |
| `.intersect()` (AND groups) | `MatchMode.all` (all rules must match) |
| OR within group | `MatchMode.any` (any rule matches) |
| `.get()` → `sbILibraryConstraint` | `SmartPlaylist.rulesJson` (JSON serialization) |
| `toString()` / `parseFromString()` | `SmartPlaylist.rulesJson` / `SmartPlaylist.parseRules()` |
| `sbILibrarySort.init(property, isAscending)` | `SmartPlaylist.sortField` + `sortOrder` |
| Property URIs (`data/1.0#genre`) | `RuleField` enum (`RuleField.genre`) |

LoonBox's model extends Songbird's with operators Songbird didn't have: `matchesRegex`, `inRange`, `between`, `inTheLast`, `notInTheLast`. It also adds `limitCount` + `limitUnit` for result limiting and `liveUpdate` for auto-refresh.

**Files:**
- Old: `components/library/base/public/sbILibraryConstraints.idl`
- New: `lib/features/playlists/domain/smart_playlist.dart`

---

## 6. Scrobbler / Last.fm Integration

### Heritage

Songbird shipped Last.fm as a built-in extension with its own XPCOM web services component.

**Old source:** `extensions/lastfm/defaults/preferences/prefs.js`
```javascript
pref("extensions.lastfm.api_url", "http://ws.audioscrobbler.com/2.0/");
pref("extensions.lastfm.loggedOut", true);
pref("extensions.lastfm.autologin", true);
pref("extensions.lastfm.scrobble", true);
```

**Old source:** `components/webservices/lastfm/public/sbILastFmWebServices.idl` — async HTTP wrapper with auth and API key management.

### LoonBox equivalent

The scrobbler is planned as the canonical first-party Lua extension (Phase 5.11), proving the extension system end-to-end:

| Old concept | New implementation |
|---|---|
| XPCOM web service component | Lua `loonbox.net.get()` / `loonbox.net.post()` |
| Preference-based config | `loonbox.storage.get/set()` (scoped per extension) |
| `on track end` implicit event | `on_track_end` Call (event hook) |
| Built-in extension | First-party extension shipped with LoonBox |
| Album art from Last.fm (`albumartlastfm` extension) | Extension with `network` permission |

**Files:**
- Old: `extensions/lastfm/`, `extensions/albumartlastfm/`
- New: Phase 5.11 (planned first-party extension)

---

## 7. Extension Ecosystem from Nightingale

The old codebase shipped with 24 extensions. Here's how each maps to LoonBox:

| Old extension | Status in LoonBox |
|---|---|
| `lastfm` | First-party Lua extension (Phase 5.11) |
| `mashTape` | Architecture informs extension slot system |
| `AlbumArt` | Built into core (`AlbumArtService`) |
| `albumartlastfm` | Lua extension via network API |
| `mpris` | Built into core (Phase 6.3, Linux media keys) |
| `systray` | Built into core (Phase 6.4) |
| `apple-mediakeys` | Built into core (Phase 6.3, macOS) |
| `foldersync` / `foldersync-ng` | Built into core (watch directories + file watcher) |
| `libnotify-notifs` | Built into core (Phase 6.5, OS notifications) |
| `hide-on-close` | Built into core (Phase 6.4, minimize to tray) |
| `playlistfolders` | Smart playlists (Phase 6.2) |
| `shoutcast` | Out of scope (streaming, post-v1) |
| `ipod` | Out of scope (device sync, post-v1) |
| `concerts` | Lua extension opportunity |
| `newreleases` | Lua extension opportunity |
| `7digital`, `amazonmusic` | Out of scope (defunct services) |
| `unity-integration` | Built into core (Linux desktop integration) |
| `apple-remote` | Out of scope (deprecated hardware) |

---

## 8. Vocabulary Lineage

| Songbird/Nightingale term | LoonBox term | Origin |
|---|---|---|
| Feathers | Feathers | Direct inheritance — Songbird coined it |
| Display Pane | Extension UI Slot | Same concept, modern name |
| Service Pane | Sidebar | Same concept |
| Faceplate | Now-Playing Bar | Same concept |
| Add-on | Extension | Simplified naming |
| — | The Nest | New (extension marketplace, post-v1) |
| — | Calls | New (event hooks to extensions) |
| — | Plumage | New (in-app feather preview/switcher) |
| — | Flock | New (community/contributor base) |

---

## Branch History

The Forgejo repository at `git.mp.ls/patrick/Loon` contains both codebases:

- **`sb-trunk-oldxul`** — The original Nightingale/Songbird XUL codebase, preserved for reference
- **`main`** — LoonBox (Flutter + Rust), the modern successor

The old code is not compiled or executed. It serves as the architectural reference from which LoonBox's design decisions are derived. This document traces those derivations.

---

*"Like your favourite old school mix tape, mix and mash up various web sources for your library enhancing pleasure."*
— mashTape extension description, Songbird (2008)
