# Contributing to LoonBox

Welcome to the Flock! We're glad you're interested in contributing to LoonBox.

## Contributor License Agreement

By submitting a pull request, you agree to the terms of our [Contributor License Agreement](CLA.md). In short: you retain copyright ownership of your contributions, and you grant MPLS LLC a license to use, modify, and relicense them. First-time contributors will be asked to confirm their agreement.

## Getting Started

1. Fork the repository
2. Follow the [build instructions](BUILDING.md) to set up your environment
3. Create a feature branch from `main`
4. Make your changes
5. Submit a pull request

## Development Guidelines

### Code Quality

- `flutter analyze` must pass with zero errors
- `cargo clippy` must pass for Rust code
- Format Dart code with `dart format`
- Format Rust code with `cargo fmt`

### Architecture

LoonBox uses a layered architecture:

| Layer | Language | Responsibility |
|-------|----------|---------------|
| **UI** | Dart/Flutter | Widgets, pages, state management (Riverpod) |
| **Services** | Dart | Business logic, API clients, database queries |
| **Bridge** | Generated | flutter_rust_bridge FFI layer (do not edit `lib/src/rust/`) |
| **Engine** | Rust | Audio decoding/output, metadata I/O, DSP, extensions |

### Branch Strategy

- `main` — stable, always buildable
- Feature branches — `feature/description` or `fix/description`
- Keep PRs focused — one feature or fix per PR

### Pull Request Process

1. Describe what changed and why
2. Link related issues
3. Ensure CI passes (Flutter analyze + Rust tests + platform builds)
4. Confirm CLA agreement

## Vocabulary

LoonBox uses specific terminology inherited from Songbird. Please use these terms consistently:

| Term | Meaning |
|------|---------|
| **Feathers** | Themes/skins — visual customization packages |
| **The Nest** | Extension and feather marketplace (future) |
| **Calls** | Event hooks dispatched to extensions |
| **Plumage** | In-app feather preview and switcher |
| **Flock** | Community and contributors (that's you!) |
| **Artist Direct** | Decentralized music distribution platform (future) |

## Good First Issues

Look for issues labeled `good first issue` on GitHub. These are tasks that are well-scoped and don't require deep knowledge of the codebase.

## Questions?

Open an issue on GitHub. We're happy to help you get started.
