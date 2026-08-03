# Product Vision — Memos One

> Version: 1.1  
> Status: Active  
> Last updated: 2026-07-31

## Positioning

**Memos One is an Offline First native client for Memos.**

- Slogan (EN): **One Client. Every Device. Your Memos.**
- Slogan (ZH): **一个客户端，连接所有设备。**

It is **not** a new note-taking product that happens to sync. It is a **first-class Memos ecosystem client** with offline-native UX.

Upstream: [https://github.com/usememos/memos](https://github.com/usememos/memos)

## Target platforms

| Platform | V1 | Later |
| -------- | -- | ----- |
| Windows  | Yes | — |
| macOS    | Yes | — |
| Android  | Yes | — |
| iOS      | No  | Planned |
| Linux    | No  | Planned |

## Workspace types

| Type | V1 | Description |
| ---- | -- | ----------- |
| **Memos Server (primary)** | Yes | Connect self-hosted Memos first; local SQLite is offline cache + SoT for UX; auto sync |
| **Local-only** | Yes (secondary) | Pure SQLite; optional for users without a server |
| **Cloud Storage** (Git / WebDAV / S3) | No | Storage Adapter reserved; post-V1 |

### Cloud-first offline model (product rule)

1. **First launch** steers users to connect a Memos instance and complete first sync.
2. After first sync, **offline edit is fully supported** (local SoT for UX).
3. When network returns, **auto-sync** (configurable): on launch, on exit, on reconnect, on interval.
4. Pure local workspace remains available as a secondary path, not the default narrative.

## Design principles

1. **Never let the network gate UX** — save completes instantly; sync is background.
2. **All product data lives locally** — memos, tags index, attachments metadata, settings, workspace, history.
3. **All network ops are retryable** — failure must not corrupt local state.
4. **Server is a sync peer**, not the sole source of truth.
5. **Stay recognizable as Memos** — minimal visual language, Material + notes-like density; ecosystem product, not a rebrand.

## V1 success criteria (MVP)

A user can:

1. Create a **Local Workspace** and fully CRUD memos offline (Markdown).
2. Create a **Memos Workspace**, sign in to a self-hosted instance, and complete **first full sync**.
3. Create / edit / delete / pin / archive memos **while offline**; changes sync when online (push + pull, LWW conflicts).
4. Search memos via **FTS** (local).
5. See clear **sync status** (idle / syncing / error / offline).
6. Run on **Windows, macOS, Android** with shared core logic.

## Explicit non-goals (V1)

| Item | Reason |
| ---- | ------ |
| Cloud Workspace (Git/WebDAV/S3) | Second product surface; Storage Adapter only reserved |
| Full AI rewrite suite in product UI | Interface reserved; not MVP critical path |
| Comments / Reactions / Shares UX | Map later; optional read-only if needed |
| Multi-user social timeline as primary UX | Client focuses on **current user's** memos |
| iOS / Linux packaging | After desktop+Android core is solid |
| Collaborative real-time editing | Out of product shape |

## User-facing trust model

Offline First products fail when sync is invisible.

V1 must show:

- Workspace connectivity state
- Last successful sync time
- Per-item dirty / error when relevant
- Global retry action
- No silent data loss without at least local history/version fields for LWW recovery

## Brand / UX direction

- Keep **Memos-adjacent** identity (simple, rounded, calm)
- Light / Dark / System themes + accent color
- Desktop: 3-pane (Workspace | List | Detail)
- Mobile: list → detail navigation

## Metrics (engineering NFRs)

See architecture NFR table. Product-level:

| Metric | Target |
| ------ | ------ |
| Cold start (desktop) | ≤ 2s to interactive shell |
| Create memo (local) | ≤ 100ms perceived |
| Search (≤100k memos) | ≤ 100ms typical |
| Offline usability | 100% after first local open (except first login / first remote import) |
