# Memos One

**One Client. Every Device. Your Memos.**

Offline-first native client for [usememos/memos](https://github.com/usememos/memos) — Windows, macOS, and Android (iOS/Linux later).

Local SQLite is the **source of truth** for UX. Your self-hosted Memos server is a **sync peer**, not a gate on every keystroke.

## What’s in the app

| Area | Description |
| ---- | ----------- |
| **Single cloud** | One Memos instance per install; no multi-workspace rail |
| **Notes** | List + detail editor, tags, pin / archive / visibility |
| **Feed** | Timeline waterfall with day spine + jump-to-day navigator |
| **Explore** | Public notes browse + public link actions |
| **Calendar** | Activity heatmap by day |
| **Offline** | Write first, queue sync; reconnect drains pending work |
| **Settings** | Appearance (theme + accent), memo prefs, sync health, cloud bind / upgrade |

Visual language: calm AppFlowy-inspired neutrals, Memos bird mark, user-selectable accent (default workspace blue `#00B5FF`).

## Status

Active development toward MVP. Architecture and process docs live under [`.ai/`](.ai/README.md).

## Connection model

| Mode | Behavior |
| ---- | -------- |
| **Memos server** | Sign in (password or Access Token); first sync then offline edit |
| **Local only** | Optional first-run path; **upgrade to cloud without wiping notes** (Settings → 云端) |
| Multi-workspace manager | **Not** in V1 UI |

## Documentation

| Audience | Path |
| -------- | ---- |
| **AI agents & design** | [`.ai/README.md`](.ai/README.md) |
| Product vision / MVP | [`.ai/product/vision.md`](.ai/product/vision.md) |
| Architecture | [`.ai/architecture/architecture.md`](.ai/architecture/architecture.md) |
| Sync spec | [`.ai/architecture/sync-spec.md`](.ai/architecture/sync-spec.md) |
| Dev process (milestones, Review, D2D) | [`.ai/standards/development-standards.md`](.ai/standards/development-standards.md) |
| Task backlog | [`.ai/tasks/backlog.md`](.ai/tasks/backlog.md) |
| UI redesign notes | [`design-system/memos-one/UI-REDESIGN-v1.md`](design-system/memos-one/UI-REDESIGN-v1.md) |
| Agent entry | [`AGENTS.md`](AGENTS.md) |

## Tech stack

- Flutter + Dart  
- Riverpod  
- Drift (SQLite)  
- Dio  
- flutter_secure_storage  
- google_fonts (Inter; runtime fetch **disabled** for Offline First)  
- flutter_markdown for V1 preview  

## Quick start

```bash
# Requires Flutter 3.x (developed on Flutter 3.44 / Dart 3.12)
export PATH="$HOME/development/flutter/bin:$PATH"   # if needed

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run -d macos   # or windows / chrome / android
```

Release build (macOS):

```bash
flutter build macos --release
open build/macos/Build/Products/Release/memos_one.app
```

Helper: `./scripts/bootstrap.sh`

## Development mode

We ship by **milestones**. Each milestone ends with:

1. **Review** — scope, architecture, quality  
2. **D2D (Design-to-Done)** — demo + evidence + sign-off  

Details: [`.ai/standards/development-standards.md`](.ai/standards/development-standards.md)

## Hard rules (architecture)

1. **UI never accesses DB or HTTP** — only UseCases / Repositories.  
2. **Local write first**, then sync queue.  
3. Do not expand milestone scope without updating `.ai/product` and `.ai/tasks`.

## License

[MIT](LICENSE) © 2026 AlexWuYh.

Memos One is an independent client for [usememos/memos](https://github.com/usememos/memos) (also MIT). It is not affiliated with the Memos project.
