# Extension UI Slots — Design Specification

This document defines every location where a LoonBox extension can inject UI
elements. Extensions never provide raw Flutter widgets — they provide
structured data (labels, icons, callbacks) and LoonBox renders the UI.

## Slot Inventory

### 1. Context Menu Items (`context_menu`)

**Where:** Right-click on tracks, albums, artists, playlists.

**Extension provides:**
- `label` — display text
- `icon` — optional Material icon name
- `target_types` — which entities: `["track", "album", "artist", "playlist"]`
- `callback` — Lua function name invoked with entity data

**Constraints:**
- Max **5** context menu items per extension
- Items appear in a separator-delimited group below native items
- Priority: extensions sorted alphabetically by extension name

**Permission required:** `ui:context_menu`

---

### 2. Toolbar Buttons (`toolbar`)

**Where:** App bar / toolbar area in the main shell.

**Extension provides:**
- `label` — tooltip text
- `icon` — Material icon name (required)
- `callback` — Lua function name invoked on click

**Constraints:**
- Max **2** toolbar buttons per extension
- Overflow: if total toolbar buttons exceed 6, extras collapse into a "more" menu

**Permission required:** `ui:toolbar`

---

### 3. Sidebar Tabs (`sidebar_tab`)

**Where:** NavigationRail sidebar, below the built-in destinations.

**Extension provides:**
- `label` — tab display text
- `icon` — Material icon name
- `panel_id` — links to a panel slot for content

**Constraints:**
- Max **1** sidebar tab per extension
- Appears below all built-in navigation items, separated by a divider
- Max **4** extension sidebar tabs total (first come first served by install order)

**Permission required:** `ui:panel`

---

### 4. Now-Playing Panels (`now_playing_panel`)

**Where:** Expanded now-playing view, below album art / queue.

**Extension provides:**
- `title` — panel header text
- `panel_id` — unique identifier
- `content_type` — `"html"` (rendered in a constrained container) or `"text"` (plain text display)
- `on_track_change` — Lua function name called with track data; returns content

**Constraints:**
- Max **2** now-playing panels per extension
- Panels are collapsible; user can reorder and hide them
- Max rendered height: 400px per panel

**Permission required:** `ui:panel`

---

### 5. Status Bar Indicators (`status_bar`)

**Where:** Bottom status area, left of the now-playing bar.

**Extension provides:**
- `label` — tooltip text
- `icon` — Material icon name
- `on_update` — Lua function name called periodically; returns display text
- `update_interval_ms` — how often to call `on_update` (min 5000ms)
- `on_tap` — optional Lua function for click handling

**Constraints:**
- Max **1** status bar indicator per extension
- Display text truncated to 20 characters
- Max **4** status bar indicators total

**Permission required:** `ui:toolbar`

---

### 6. Notification Toasts (`notification`)

**Where:** Overlay toast notifications (bottom-right on desktop).

**Extension provides:**
- `title` — toast title
- `body` — toast body text
- `duration_ms` — display duration (default 3000, max 10000)
- `icon` — optional Material icon name

**Constraints:**
- Max **1** visible toast per extension at a time
- Rate limited: max 3 toasts per minute per extension
- Toasts auto-dismiss; not interactive

**Permission required:** none (all extensions can show toasts)

---

## Slot Registration Protocol

### In Manifest (`extension.json`)

Extensions declare which slots they want in their manifest:

```json
{
  "id": "lyrics-provider",
  "name": "Lyrics",
  "version": "1.0.0",
  "permissions": ["ui:panel", "network:*", "player:read"],
  "entry": "main.lua",
  "ui": {
    "slots": [
      {
        "type": "now_playing_panel",
        "panel_id": "lyrics_panel",
        "title": "Lyrics",
        "content_type": "text"
      },
      {
        "type": "context_menu",
        "label": "Search Lyrics",
        "icon": "lyrics",
        "target_types": ["track"]
      }
    ]
  }
}
```

### At Runtime

1. Extension manager reads manifest `ui.slots` during install/enable
2. Each slot declaration is validated against the extension's granted permissions
3. Valid slots are registered in a global `SlotRegistry`
4. Flutter widgets at each slot location watch the registry and render accordingly
5. When an extension is disabled/uninstalled, its slots are removed immediately

### Conflicting Registrations

- If two extensions register conflicting slots (e.g., same toolbar position),
  they are ordered by extension install timestamp
- If a slot type is at capacity, the newest extensions' slots are hidden
  (but still registered — they appear if another extension is disabled)

## Lua Callback Contract

When a slot triggers a Lua callback, it passes a table:

```lua
-- Context menu callback
function on_context_menu(context)
  -- context.type = "track" | "album" | "artist" | "playlist"
  -- context.id = database ID
  -- context.title = display title
  -- context.artist = artist name (tracks/albums only)
  -- context.album = album name (tracks only)
  -- context.file_path = file path (tracks only)
end

-- Now-playing panel callback
function on_track_change(track)
  -- track.title, track.artist, track.album, track.file_path, track.duration_ms
  -- Return: string content to display
  return "Lyrics content here..."
end
```

## Rendering

Extensions never provide raw widgets. LoonBox renders all slot UI using its own
widget tree, styled by the active feather. This ensures:

- Visual consistency across all extensions
- No extension can break the app's layout
- Feather changes automatically update extension UI
- Accessibility (Semantics) is handled by LoonBox, not extensions
