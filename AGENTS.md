# Agent Instructions — Memos One

You are working on **Memos One**, an Offline First Flutter client for [usememos/memos](https://github.com/usememos/memos).

**Product shape (current):** single Memos connection (no multi-workspace rail), AppFlowy-like calm UI, timeline feed, local-first sync, optional local-only with non-destructive cloud upgrade.

## Read first

1. [`.ai/README.md`](.ai/README.md) — documentation index  
2. [`.ai/product/vision.md`](.ai/product/vision.md) — MVP scope  
3. [`.ai/tasks/milestones.md`](.ai/tasks/milestones.md) + [`.ai/tasks/backlog.md`](.ai/tasks/backlog.md) — what to build now  
4. [`.ai/standards/development-standards.md`](.ai/standards/development-standards.md) — milestones, Review, **D2D**  
5. [`.ai/architecture/architecture.md`](.ai/architecture/architecture.md) — system design  
6. [`design-system/memos-one/UI-REDESIGN-v1.md`](design-system/memos-one/UI-REDESIGN-v1.md) — shipped shell / feed visual notes  

## Hard rules

1. **UI never accesses DB or HTTP** — only UseCases / Repositories.  
2. **Local write first**, then sync queue — never HTTP-then-SQLite for UX success.  
3. **Do not expand milestone scope** without updating `.ai/product` and `.ai/tasks`.  
4. All AI-facing docs go under **`.ai/`** (not random root markdown).  
5. End of milestone: complete **Review + D2D** templates before starting the next milestone.  
6. Prefer small vertical tasks; mark backlog statuses when finishing work.  
7. **Brand accent** comes from `Theme.of(context).colorScheme.primary` (user seed) — do not hardcode `AppTheme.accent` for interactive chrome.

## Toolchain notes

- Flutter SDK may need install (`flutter` not assumed globally).  
- After SDK available: `flutter pub get`, `flutter analyze`, `flutter test`.  
- Platform runners: `flutter create . --platforms=windows,macos,android` if missing.  
- `GoogleFonts.config.allowRuntimeFetching = false` (Offline First).

## Current focus

See **Active focus** in [`.ai/tasks/backlog.md`](.ai/tasks/backlog.md).
