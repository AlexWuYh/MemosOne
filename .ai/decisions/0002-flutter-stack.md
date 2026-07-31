# ADR 0002: Flutter + Drift + Riverpod

- Status: Accepted
- Date: 2026-07-31

## Context

Need one codebase for Windows, macOS, and Android with native-feel UI and strong local database support. Electron is heavier and less native. Kotlin Multiplatform + Swift doubles UI cost.

## Decision

- **Flutter** for UI and platforms
- **Drift (SQLite)** for typed local DB + FTS5 path
- **Riverpod** as sole app state system
- **Dio** for HTTP
- **flutter_secure_storage** for tokens (not Hive business data)

## Consequences

- Shared logic speed; desktop plugin gaps require spikes (tray, global hotkeys).
- Team must know Dart/Flutter.
- Codegen (build_runner) is part of the workflow.
