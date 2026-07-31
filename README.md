# Memos One

**One Client. Every Device. Your Memos.**

Offline-first native client for [Memos](https://github.com/usememos/memos) — Windows, macOS, and Android (iOS/Linux later).

Local SQLite is the source of truth. Your Memos server is a sync peer.

## Status

Early scaffold (Milestone **M0**). Architecture and process docs live under [`.ai/`](.ai/README.md).

## Documentation (start here)

| Audience | Path |
| -------- | ---- |
| **AI agents & deep design** | [`.ai/README.md`](.ai/README.md) |
| Product vision / MVP | [`.ai/product/vision.md`](.ai/product/vision.md) |
| Architecture V1.1 | [`.ai/architecture/architecture.md`](.ai/architecture/architecture.md) |
| Dev process (milestones, Review, D2D) | [`.ai/standards/development-standards.md`](.ai/standards/development-standards.md) |
| Task backlog | [`.ai/tasks/backlog.md`](.ai/tasks/backlog.md) |
| Agent entry | [`AGENTS.md`](AGENTS.md) |

## Tech stack

- Flutter + Dart  
- Riverpod  
- Drift (SQLite)  
- Dio  
- flutter_secure_storage  

## Quick start

```bash
# Requires Flutter 3.x / Dart 3.5+
flutter pub get
flutter test
flutter run -d macos   # or windows / android
```

If platform folders are missing after clone:

```bash
flutter create . --project-name memos_one --platforms=windows,macos,android
flutter pub get
```

## Development mode

We ship by **milestones**. Each milestone ends with:

1. **Review** — scope, architecture, quality  
2. **D2D (Design-to-Done)** — demo + evidence + sign-off  

Details: [`.ai/standards/development-standards.md`](.ai/standards/development-standards.md)

## Workspace types

| Type | V1 |
| ---- | -- |
| Local (offline only) | Yes |
| Memos Server (self-hosted sync) | Yes |
| Cloud (Git / WebDAV / S3) | Post-V1 |

## License

TBD (align with distribution goals; respect Memos upstream license when linking).
