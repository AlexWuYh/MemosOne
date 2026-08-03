# Memos One — Architecture Design Specification (V1.1)

> Version: **1.1**  
> Status: **Active**  
> Supersedes: `architecture-v1.0-draft.md`  
> Related: [memos-compatibility.md](./memos-compatibility.md), [sync-spec.md](./sync-spec.md), [data-model.md](./data-model.md)

---

## 1. Goals

Build an **Offline First** Flutter client for Memos where:

- Local SQLite is the **Source of Truth (SoT)**
- Memos Server is a **sync peer**
- UI never depends on network success for basic CRUD
- Architecture stays clean for multi-year AI + human collaboration

### 1.1 Design principles

| # | Principle | Implication |
| - | --------- | ----------- |
| P1 | Network never gates UX | Optimistic local write → background sync |
| P2 | All data local | Memo, tag index, attachment meta, settings, workspace, sync queue |
| P3 | Network always retryable | Queue + backoff + terminal error surfacing |
| P4 | Server ≠ SoT | Pull merges into local; never wipe dirty local blindly |
| P5 | Memos-first compatibility | Domain models map to API v1; not generic notes-only |

---

## 2. Workspace model

Unified abstraction: **Workspace** = isolated data plane.

```
┌─────────────────────────────────────────────────────┐
│ App                                                 │
│  ┌──────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │ Local WS │  │ Memos WS     │  │ Cloud WS (V2) │  │
│  │ SQLite   │  │ SQLite+Sync  │  │ SQLite+Adapter│  │
│  └──────────┘  └──────────────┘  └───────────────┘  │
└─────────────────────────────────────────────────────┘
```

| Type | Persistence | Sync |
| ---- | ----------- | ---- |
| `local` | Shared app SQLite, scoped by `workspaceId` | None |
| `memos` | Shared app SQLite, scoped by `workspaceId` | Sync Engine ↔ Memos API v1 |
| `cloud` | Reserved | Storage Adapter (Git/WebDAV/S3) — **not V1** |

Rules:

- One active workspace at a time in UI (multi-workspace list supported)
- **V1 persistence:** single Drift DB (`memos_one.sqlite`) with logical isolation — see [ADR 0004](../decisions/0004-single-db-multi-workspace.md). `databasePath` on Workspace is reserved, not multi-file SoT.
- Credentials never live in the business DB (secure storage only)
- Full pull + remote-delete reconcile on schedule / Sync now; push drains every poll

---

## 3. Layered architecture

### 3.1 Logical layers

```
┌──────────────────────────────────────────────┐
│ Presentation                                 │
│  Pages / Widgets / Dialogs / Theme           │
└─────────────────────┬────────────────────────┘
                      │ events / watch state
                      ▼
┌──────────────────────────────────────────────┐
│ Application                                  │
│  UseCases / Notifiers (Riverpod) / Commands  │
└─────────────────────┬────────────────────────┘
                      │ domain ports
                      ▼
┌──────────────────────────────────────────────┐
│ Domain                                       │
│  Entities / Repository interfaces / Policies │
└─────────────────────┬────────────────────────┘
                      │ implementations
          ┌───────────┴───────────┐
          ▼                       ▼
┌──────────────────┐    ┌──────────────────────┐
│ Local Datasource │    │ Remote Datasource    │
│ Drift / SQLite   │    │ Dio / Memos API v1   │
└────────┬─────────┘    └──────────┬───────────┘
         │                         │
         │      ┌──────────────────┘
         │      │
         ▼      ▼
┌──────────────────────────────────────────────┐
│ Sync Engine (Infrastructure + App worker)    │
│  Queue · Worker · Conflict · Auth gate       │
└──────────────────────────────────────────────┘
```

### 3.2 Dependency rules

| From | May depend on |
| ---- | ------------- |
| Presentation | Application, Domain (types only), shared widgets |
| Application | Domain interfaces |
| Domain | Nothing outward (pure Dart) |
| Infrastructure | Domain interfaces (implements them) |
| Feature A | Feature B **interfaces only** (prefer shared/domain) |

**Forbidden:**

- Widget → Drift / Dio
- UseCase → concrete Dio client without repository
- Cross-feature import of another feature's `data/` or `presentation/`

### 3.3 Command vs sync paths

**Command path (user action):**

```
UI → UseCase → Repository
              → write SQLite
              → mark dirty / enqueue SyncTask
              → emit stream update (UI refresh)
```

**Sync path (background):**

```
SyncWorker → claim SyncTask / pull remote
           → Remote API
           → apply result via Repository (clear dirty, map serverId)
           → update sync status streams
```

UI **subscribes** to data + sync status; it does **not** orchestrate HTTP.

---

## 4. Technology stack

| Concern | Choice | Notes |
| ------- | ------ | ----- |
| Framework | **Flutter** 3.x | Windows / macOS / Android first |
| Language | Dart 3.5+ | null-safety, strict analyzer |
| State | **Riverpod** (+ codegen optional) | Single state solution |
| Local DB | **SQLite + Drift** | Migrations, FTS5, type-safe |
| HTTP | **Dio** | Interceptors for auth, logging |
| Secure secrets | **flutter_secure_storage** | tokens, not Hive |
| Preferences | **shared_preferences** | theme, window chrome, last workspace id |
| Markdown | **flutter_markdown** (V1) | Editor upgrade path: super_editor later |
| IDs | **uuid** v4 for local primary identity | see data-model |
| Logging | **logger** | no `print` in prod paths |

### 4.1 Explicit non-choices (V1)

- GetX, Bloc as app-wide state (Riverpod only)
- Hive for business data or tokens
- `LIKE '%q%'` as primary search
- Electron

---

## 5. Offline First contract

### 5.1 Source of truth

**Local DB is SoT for all user-visible content** in a workspace.

Remote is:

- Initial import source (first sync)
- Ongoing merge peer
- Never required for read/list/edit after local data exists

### 5.2 Write protocol (mandatory)

```
User saves memo
  → Repository.create/update/delete (SQLite)   # must succeed for UX success
  → UI already shows new state
  → SyncTask enqueued (if workspace.type == memos)
  → Worker pushes when online + authenticated
```

**Forbidden pattern:**

```
UI → HTTP → onSuccess → SQLite   # NOT ALLOWED
```

### 5.3 Read protocol

```
UI watches Repository streams / queries against SQLite only
Pull sync updates SQLite in background → streams emit → UI updates
```

---

## 6. Sync Engine (overview)

Full protocol: [sync-spec.md](./sync-spec.md)

Components:

| Component | Role |
| --------- | ---- |
| SyncQueue | Durable table of pending ops |
| SyncWorker | Poll / event-driven executor |
| Puller | Incremental/full remote fetch |
| ConflictResolver | V1: Last-Write-Wins |
| AuthGate | Pause queue on 401; resume after re-auth |

V1 conflict: **Last Write Wins** using comparable timestamps (prefer server `updateTime` when both sides clean; dirty local wins until pushed — see sync-spec).

---

## 7. Memos compatibility posture

Full matrix: [memos-compatibility.md](./memos-compatibility.md)

Summary for V1:

| Area | Support |
| ---- | ------- |
| Auth (username/password or access token as applicable) | Required |
| Memo CRUD | Required |
| Memo pin / state (normal/archived) | Required |
| Visibility | Store + round-trip |
| Attachments binary | Metadata + upload/download basic |
| Tags | Derived from content + local index |
| Relations / comments / reactions / shares | Out of V1 UI (API ignore or defer) |
| Target API | Memos **API v1** (`/api/v1/...`) |

---

## 8. Data model (summary)

Full schema: [data-model.md](./data-model.md)

Identity rules (critical):

| Field | Role |
| ----- | ---- |
| `localId` (UUID) | **Primary key** everywhere local |
| `serverName` | Memos resource name e.g. `memos/123` (nullable until first push success) |
| `workspaceId` | Tenant isolation |

Sync state machine fields: `syncStatus`, `dirty`, `deletedAt` (soft delete), `updatedAtLocal`, `updatedAtServer`, `lastError`.

---

## 9. Repository design

Repositories are the **only** data entry for features.

Example `MemoRepository`:

```dart
abstract class MemoRepository {
  Stream<List<Memo>> watchAll({MemoQuery query});
  Future<Memo?> getByLocalId(String localId);
  Future<Memo> create(NewMemo input);
  Future<Memo> update(String localId, MemoPatch patch);
  Future<void> softDelete(String localId);
  Future<void> pin(String localId, bool pinned);
  Future<void> archive(String localId, bool archived);
  Future<List<Memo>> search(SearchQuery query);
}
```

Internals may use Local + Queue; Application layer must not care.

---

## 10. Search

- Engine: **SQLite FTS5** (Drift virtual table)
- Content: memo body (+ optional title/snippet)
- Filters: tag, date range, workspace (implicit), pinned/archived
- Ban: leading-wildcard `LIKE` as primary path

---

## 11. Presentation architecture

### Desktop

```
+------------+------------------+------------------+
| Workspace  | Memo List        | Memo Detail      |
| + Sync     | + Filters        | + Editor         |
|   badge    |                  |                  |
+------------+------------------+------------------+
```

### Mobile

```
Memo List  →  Memo Detail / Editor
```

### Sync UX (required)

- Global: Online / Offline / Syncing / Error
- Last sync timestamp
- Manual “Sync now”
- Task error list (debug / settings)

Themes: Light / Dark / System + accent.

---

## 12. AI capability (reserved, not V1 path)

```text
AIService
  summarize / rewrite / translate / generateTitle / extractTags
```

Providers later: OpenAI, Claude, Gemini, Ollama, and optionally Memos server AI.

Rules:

- Interface only in V1 skeleton
- Must work offline-safe (queue or disable when no key/network)
- Never block save path

---

## 13. Directory structure

```text
lib/
  app/                 # bootstrap, router, root theme
  core/                # constants, errors, theme tokens, utils
  domain/              # shared domain entities & repository ports (cross-feature)
  application/         # shared application services if needed
  infrastructure/      # db, network, storage, sync engine
  feature/
    memo/
    workspace/
    search/
    sync/
    setting/
    ai/                # stub
  shared/              # pure UI widgets, extensions
```

Per feature (vertical slice):

```text
feature/memo/
  domain/         # entities, repo interface (if feature-local)
  application/    # providers, use cases
  data/           # repository impl adapters (thin)
  presentation/   # pages, widgets
```

Prefer putting **stable ports** under `lib/domain` when shared.

---

## 14. Security

| Topic | V1 rule |
| ----- | ------- |
| Access token | `flutter_secure_storage` only |
| Server URL | preferences / workspace registry table (non-secret) |
| TLS | Default validate; optional “allow insecure” for LAN self-signed (explicit user toggle) |
| DB encryption | SQLCipher reserved (NFR); not required MVP |
| Logout | Clear secure token; optional wipe local DB |
| Logs | Never log tokens / full Authorization headers |

---

## 15. Non-functional requirements

| Category | Requirement |
| -------- | ----------- |
| Cold start (desktop) | ≤ 2s interactive |
| Create memo local | ≤ 100ms to persisted + UI |
| Search | ≤ 100ms @ 100k memos (warm) |
| Sync | Async; never block typing/save |
| Offline | 100% after local data present |
| Extensibility | New remote backend via adapter, no domain rewrite |
| Testability | Domain + sync pure logic unit-tested |

---

## 16. Development milestones (summary)

See [../tasks/milestones.md](../tasks/milestones.md).

| M | Name | Outcome |
| - | ---- | ------- |
| M0 | Bootstrap | Flutter project, CI-ready skeleton, docs |
| M1 | Local core | Local WS + Memo CRUD + Markdown |
| M2 | Memos auth & API | Login, client, token, smoke list |
| M3 | Sync Engine | Queue, push, pull, LWW, status UX |
| M4 | Search & attachments | FTS5, basic files |
| M5 | Desktop polish | Shortcuts, window state, tray (stretch) |
| M6 | Android polish | Share intent, back nav, perf |
| M7 | Hardening | Encryption spike, conflict UX, quality bar |
| M8+ | Post-V1 | AI, cloud adapters, iOS/Linux |

Each milestone ends with **Review + D2D** ([development-standards.md](../standards/development-standards.md)).

---

## 17. AI coding constraints (normative)

1. UI must not access DB or network directly.
2. Business logic must not live in Widgets.
3. Mutations: local first, then sync queue.
4. Repository depends on abstractions, not concrete Dio/Drift types in domain.
5. Feature isolation: no cross-feature implementation imports.
6. Prefer extension via interfaces (OCP).
7. Async paths: retry, cancel, user-visible status.
8. No feature may break Offline-first.
9. Scope changes require updating `.ai/product/vision.md` and tasks.
10. Public architecture changes require ADR under `.ai/decisions/`.

---

## 18. Open questions (tracked)

| ID | Question | Default until decided |
| -- | -------- | --------------------- |
| Q1 | Exact auth method set for target Memos versions | Password login + access token header |
| Q2 | Attachment size limits | 25MB soft warn; stream upload later |
| Q3 | Multi-account same server | Multiple workspaces |
| Q4 | Editor upgrade timing | After M4 if markdown UX insufficient |

---

## 19. Changelog

| Version | Date | Notes |
| ------- | ---- | ----- |
| 1.0 Draft | — | Initial product architecture draft |
| 1.1 | 2026-07-31 | MVP scope cut; Memos matrix; sync path clarified; security; ID strategy; D2D process link |
