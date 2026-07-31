# Milestone Roadmap

> Execution mode: [development-standards.md](../standards/development-standards.md)  
> Detailed tasks: [backlog.md](./backlog.md)

---

## Overview

| ID | Name | Goal | Exit |
| -- | ---- | ---- | ---- |
| **M0** | Bootstrap | Repo, scaffold, `.ai` docs, toolchain notes | Review + D2D |
| **M1** | Local core | Local workspace + memo CRUD + Markdown UI | Review + D2D |
| **M2** | Memos API & auth | Login, API client, read remote memos into local | Review + D2D |
| **M3** | Sync Engine | Queue, push/pull, LWW, sync status UX | Review + D2D |
| **M4** | Search & attachments | FTS5 search, basic attachment sync | Review + D2D |
| **M5** | Desktop polish | Window state, shortcuts, optional tray | Review + D2D |
| **M6** | Android polish | Share-in, navigation, performance | Review + D2D |
| **M7** | Hardening | History UX, conflict visibility, security spikes | Review + D2D |
| **M8+** | Post-V1 | AI providers, cloud adapters, iOS/Linux | Separate planning |

---

## M0 — Bootstrap (current)

**Outcome:** Developers/agents can open the repo, understand architecture, and run/analyze once Flutter is installed.

**In scope:**

- Git repository
- Flutter package scaffold (`lib/`, tests, analysis)
- `.ai/**` documentation set (vision, architecture, standards, tasks)
- Root README + AGENTS.md pointers
- Placeholder app boots (when Flutter available)

**Out of scope:** Real memo CRUD, network

**D2D demo:** Open docs index; `flutter pub get && flutter test` when SDK present; app shows scaffold home.

---

## M1 — Local core

**Outcome:** Pure offline note-taking works end-to-end.

**In scope:**

- Workspace create (local)
- Drift schema v1 (memo, tags, history stub)
- Memo create/edit/delete/pin/archive
- Markdown preview
- Desktop 3-pane / mobile list-detail shell
- Theme light/dark/system

**Out of scope:** Memos server, sync, FTS polish

**D2D demo:** Airplane mode; create 3 memos; restart app; data persists; pin/archive/delete work.

---

## M2 — Memos API & auth

**Outcome:** Can connect to a Memos instance and import user's memos.

**In scope:**

- Server URL + login UI
- Secure token storage
- Dio client + DTO mappers
- First full pull into SQLite
- Compatibility fail-fast messaging

**Out of scope:** Full offline edit push queue (may still be read-mostly + local dirty flags scaffolding)

**D2D demo:** Login to test instance; memos list matches server for current user; token survives restart; logout clears token.

---

## M3 — Sync Engine

**Outcome:** True offline-first bidirectional sync.

**In scope:**

- SyncTask queue + worker + backoff
- Push create/update/delete
- Incremental/full pull
- LWW + memo_history on lost conflicts
- AuthGate on 401
- Sync status UX

**D2D demo:** Edit offline; go online; changes appear on server; edit on server (or second client); pull reflects LWW rules; 401 pauses with re-login.

---

## M4 — Search & attachments

**Outcome:** Fast local search; images/files usable.

**In scope:**

- FTS5 + filters
- Attachment local store + basic upload/download
- Image preview in detail view

**D2D demo:** Search  keyword among many memos; attach image offline then sync; reopen shows cached file.

---

## M5 — Desktop polish

**Outcome:** Feels like a native desktop notes client.

**In scope:**

- Window size/position restore
- Keyboard shortcuts (new, search, sync)
- Optional system tray / close-to-tray (stretch)

**D2D demo:** Shortcut-driven create + search; window state restored.

---

## M6 — Android polish

**Outcome:** Daily-driver capable on phone.

**In scope:**

- Share intent → new memo
- Back stack / predictive back sanity
- List performance (large datasets)

**D2D demo:** Share text from another app into Memos One; scroll large list smoothly.

---

## M7 — Hardening (V1 freeze)

**Outcome:** V1 quality bar.

**In scope:**

- History recovery minimal UI
- Dead letter queue UI
- SQLCipher / encryption spike notes
- Self-signed TLS option
- Test suite expansion for sync
- Performance pass on NFR targets

**D2D demo:** Full MVP script from vision success criteria; no P0; NFRs measured or justified.

---

## M8+ — Post-V1 (not scheduled in detail)

- AIService providers
- Cloud storage adapters
- Relations/comments if product asks
- iOS / Linux packaging
