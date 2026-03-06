# Building LoonBox

## Prerequisites

- **Flutter SDK** — 3.x stable channel ([install](https://docs.flutter.dev/get-started/install))
- **Rust toolchain** — stable, via [rustup](https://rustup.rs/)
- **flutter_rust_bridge_codegen** — `cargo install flutter_rust_bridge_codegen`

### Platform-specific

**Windows:**
- Visual Studio 2022 with "Desktop development with C++" workload

**Linux:**
```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libasound2-dev
```

**macOS:**
- Xcode command line tools: `xcode-select --install`

## Build & Run

```bash
git clone https://github.com/mplsllc/LoonBox.git
cd LoonBox/loon_app

# Install Flutter dependencies
flutter pub get

# Generate Rust FFI bindings (required after any Rust API changes)
flutter_rust_bridge_codegen generate

# Run in debug mode
flutter run
```

For a release build:
```bash
flutter build windows    # or linux, macos
```

## Project Structure

```
loon_app/
├── lib/                    # Flutter/Dart code
│   ├── database/           # Drift schema, tables, migrations
│   ├── features/           # UI features (shell, player, playlists)
│   ├── l10n/               # Localization (ARB files)
│   ├── services/           # Audio, album art, MusicBrainz, tray, etc.
│   ├── src/rust/           # Generated FRB bindings (do not edit)
│   └── theme/              # Feather theming system
├── rust/                   # Rust workspace
│   ├── src/                # FRB bridge (api.rs, internal/)
│   ├── loonbox_audio/      # Audio engine (decoder, output, DSP, EQ)
│   ├── loonbox_metadata/   # Metadata reader/writer (lofty)
│   ├── loonbox_bridge/     # Shared types between crates
│   └── loonbox_extensions/ # Extension system (Lua, planned)
├── assets/                 # Icons, fonts
├── windows/                # Windows runner
├── linux/                  # Linux runner
└── macos/                  # macOS runner
```

## Common Issues

**FRB codegen not found:**
If `flutter_rust_bridge_codegen` isn't in your PATH, use the full path:
```bash
# Windows
%USERPROFILE%\.cargo\bin\flutter_rust_bridge_codegen.exe generate

# Linux/macOS
~/.cargo/bin/flutter_rust_bridge_codegen generate
```

**Windows LNK1168 (cannot open .exe for writing):**
The app is still running. Close it (check system tray) or kill the process before rebuilding.

**Rust compilation errors after pulling:**
Run `flutter_rust_bridge_codegen generate` again — the FFI bindings may need regenerating.

**`flutter analyze` warnings:**
The codebase should pass `flutter analyze` with zero errors. Warnings about `unnecessary_underscores` in generated code are expected and can be ignored.
