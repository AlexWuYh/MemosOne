# Development Task Backlog

> Status legend: `todo` | `doing` | `done` | `blocked` | `deferred`  
> Priority: P0 > P1 > P2 > P3  
> Process: [development-standards.md](../standards/development-standards.md)

---

## M0 — Bootstrap

| ID | Priority | Status | Task | Acceptance criteria |
| -- | -------- | ------ | ---- | ------------------- |
| M0-T01 | P0 | done | Initialize git repository on `main` | Repo exists; default branch `main` |
| M0-T02 | P0 | done | Create Flutter package scaffold (`pubspec`, `lib/`, `test/`) | App entry + smoke test file present |
| M0-T03 | P0 | done | Create `.ai/` documentation tree | Index + architecture + standards + tasks readable |
| M0-T04 | P0 | done | Write product vision & MVP scope | `product/vision.md` with non-goals |
| M0-T05 | P0 | done | Write architecture V1.1 + sync + data-model + compatibility | Four architecture docs complete |
| M0-T06 | P0 | done | Write development standards (milestones, Review, D2D) | Standards + templates present |
| M0-T07 | P1 | done | Root README + AGENTS.md pointing to `.ai` | New contributor knows where to read |
| M0-T08 | P1 | done | `.gitignore`, `analysis_options`, `.env.example` | Standard Flutter ignores + lints |
| M0-T09 | P1 | todo | Install Flutter SDK locally / CI and run `flutter pub get` | Dependencies resolve |
| M0-T10 | P1 | todo | Generate platform folders (`flutter create .`) for win/mac/android | Can build debug targets |
| M0-T11 | P2 | todo | Add GitHub Actions: analyze + test | CI green on PR |
| M0-T12 | P1 | todo | M0 Review + D2D | Templates filled under `tasks/reviews/` |

---

## M1 — Local core

| ID | Priority | Status | Task | Acceptance criteria |
| -- | -------- | ------ | ---- | ------------------- |
| M1-T01 | P0 | todo | App-level workspace registry (local type) | Create/list/switch local workspaces |
| M1-T02 | P0 | todo | Drift DB bootstrap per workspace | Open DB at `databasePath`; schema v1 |
| M1-T03 | P0 | todo | `Memo` table + domain entity + repository port | CRUD against SQLite only |
| M1-T04 | P0 | todo | Memo list + detail UI (desktop 3-pane shell) | Select memo shows content |
| M1-T05 | P0 | todo | Create / edit memo (local-first save ≤100ms path) | Restart persists content |
| M1-T06 | P0 | todo | Soft delete + pin + archive | Filters work; default hides deleted |
| M1-T07 | P1 | todo | Markdown preview (flutter_markdown) | Renders basic MD |
| M1-T08 | P1 | todo | Tag parse + `Tag`/`MemoTag` index on save | Tags extracted from `#foo` |
| M1-T09 | P1 | todo | Theme: light/dark/system + accent seed | Preference persists |
| M1-T10 | P1 | todo | Mobile navigation: list → detail | Back returns to list |
| M1-T11 | P1 | todo | `memo_history` on user edit (snapshot) | Last N snapshots stored |
| M1-T12 | P2 | todo | Empty states & basic settings page | No crash on empty DB |
| M1-T13 | P1 | todo | Unit tests for memo repository local ops | Tests green |
| M1-T14 | P1 | todo | M1 Review + D2D | Offline demo recorded in d2d doc |

---

## M2 — Memos API & auth

| ID | Priority | Status | Task | Acceptance criteria |
| -- | -------- | ------ | ---- | ------------------- |
| M2-T01 | P0 | todo | Memos workspace type + server URL config UI | Validation for URL |
| M2-T02 | P0 | todo | Auth remote datasource + login use case | Token stored in secure storage |
| M2-T03 | P0 | todo | Dio client: base URL, auth interceptor, logging scrub | 401 detectable |
| M2-T04 | P0 | todo | Memo DTO ↔ domain mapper | name/content/visibility/times map |
| M2-T05 | P0 | todo | ListMemos pagination pull (full import) | Local rows get `serverName` |
| M2-T06 | P1 | todo | Instance/user info fetch for header UI | Shows username |
| M2-T07 | P1 | todo | Compatibility fail-fast on unsupported API | Clear error message |
| M2-T08 | P1 | todo | Logout clears token; optional keep local cache | Secure key removed |
| M2-T09 | P1 | todo | Manual “Pull now” without full push engine | Imports updates (read path) |
| M2-T10 | P2 | todo | Self-signed TLS toggle (default off) | Documented risk in UI |
| M2-T11 | P1 | todo | Tests with mocked Dio | Login + list mapping covered |
| M2-T12 | P1 | todo | M2 Review + D2D | Live or mock server demo |

---

## M3 — Sync Engine

| ID | Priority | Status | Task | Acceptance criteria |
| -- | -------- | ------ | ---- | ------------------- |
| M3-T01 | P0 | todo | `sync_task` table + enqueue API | Tasks durable across restart |
| M3-T02 | P0 | todo | Task coalescing rules | create+update / multi-update / create+delete |
| M3-T03 | P0 | todo | SyncWorker loop + backoff | Respects `nextAttemptAt` |
| M3-T04 | P0 | todo | Push create/update/delete | serverName bound; dirty cleared |
| M3-T05 | P0 | todo | Pull incremental + full reconcile | Cursor stored |
| M3-T06 | P0 | todo | ConflictResolver LWW + history on loss | Spec cases pass tests |
| M3-T07 | P0 | todo | AuthGate pauses on 401 | UI shows re-login |
| M3-T08 | P0 | todo | Sync status stream + UI badge | idle/syncing/offline/error |
| M3-T09 | P1 | todo | Manual Sync now | Drain push then pull |
| M3-T10 | P1 | todo | Dead letter handling | dead tasks visible in settings |
| M3-T11 | P0 | todo | Sync unit tests (7 cases from sync-spec §12) | All green |
| M3-T12 | P1 | todo | M3 Review + D2D | Offline edit → online push demo |

---

## M4 — Search & attachments

| ID | Priority | Status | Task | Acceptance criteria |
| -- | -------- | ------ | ---- | ------------------- |
| M4-T01 | P0 | todo | FTS5 virtual table + search repository | Query returns ranked hits |
| M4-T02 | P1 | todo | Search UI (desktop + mobile) | Debounced query |
| M4-T03 | P1 | todo | Filters: tag, date, pinned/archived | Composable query |
| M4-T04 | P0 | todo | Attachment entity + local file store | File copied into app dir |
| M4-T05 | P0 | todo | Upload/download via attachment API | Bound remote refs after sync |
| M4-T06 | P1 | todo | Image preview in memo detail | Local path preferred |
| M4-T07 | P2 | todo | Size warning threshold | User notified >25MB |
| M4-T08 | P1 | todo | Search/attachment tests | Core cases green |
| M4-T09 | P1 | todo | M4 Review + D2D | Search + attach demo |

---

## M5 — Desktop polish

| ID | Priority | Status | Task | Acceptance criteria |
| -- | -------- | ------ | ---- | ------------------- |
| M5-T01 | P1 | todo | Persist window size/position | Restored on launch |
| M5-T02 | P1 | todo | Shortcuts: new memo, search focus, sync | Documented in settings |
| M5-T03 | P2 | todo | Global hotkey (platform-dependent) | Spike then implement or defer |
| M5-T04 | P3 | todo | System tray / close-to-tray | Stretch; defer if unstable |
| M5-T05 | P2 | todo | Desktop visual density pass | Usable on 13–27\" |
| M5-T06 | P1 | todo | M5 Review + D2D | Shortcut demo |

---

## M6 — Android polish

| ID | Priority | Status | Task | Acceptance criteria |
| -- | -------- | ------ | ---- | ------------------- |
| M6-T01 | P1 | todo | Share intent → create memo | Text shared becomes content |
| M6-T02 | P1 | todo | Navigation/back correctness | No orphan routes |
| M6-T03 | P1 | todo | Large list performance (lazy + keys) | Smooth scroll @10k if possible |
| M6-T04 | P2 | todo | Notifications stub for sync errors | Optional |
| M6-T05 | P3 | todo | Home screen widget spike | Defer if costly |
| M6-T06 | P1 | todo | M6 Review + D2D | Share-in demo on device/emulator |

---

## M7 — Hardening (V1 freeze)

| ID | Priority | Status | Task | Acceptance criteria |
| -- | -------- | ------ | ---- | ------------------- |
| M7-T01 | P1 | todo | History recovery minimal UI | Restore prior content |
| M7-T02 | P1 | todo | Expand sync edge-case tests | Uncertainty create, remote delete |
| M7-T03 | P1 | todo | NFR measurement notes (start, search) | Documented numbers |
| M7-T04 | P2 | todo | SQLCipher / encryption spike | ADR written |
| M7-T05 | P1 | todo | Security review pass (tokens, logs) | Checklist signed |
| M7-T06 | P1 | todo | Full MVP acceptance script | Vision success criteria met |
| M7-T07 | P1 | todo | M7 Review + D2D = **V1 candidate** | Tag `v0.1.0` or `m7-d2d` |

---

## M8+ — Post-V1 (backlog seed only)

| ID | Priority | Status | Task |
| -- | -------- | ------ | ---- |
| M8-T01 | P3 | deferred | AIService interface + one provider |
| M8-T02 | P3 | deferred | Cloud storage adapter SPI |
| M8-T03 | P3 | deferred | WebDAV adapter |
| M8-T04 | P3 | deferred | S3 adapter |
| M8-T05 | P3 | deferred | Git adapter |
| M8-T06 | P3 | deferred | Memo relations UI |
| M8-T07 | P3 | deferred | Comments / reactions |
| M8-T08 | P3 | deferred | iOS target |
| M8-T09 | P3 | deferred | Linux target |
| M8-T10 | P3 | deferred | super_editor migration |

---

## Active focus

**Current milestone: M0 — Bootstrap**

Next actions:

1. Complete M0-T09–T12 when Flutter SDK is available  
2. Close M0 with Review + D2D  
3. Start M1-T01

---

## Change log

| Date | Change |
| ---- | ------ |
| 2026-07-31 | Initial backlog created from architecture V1.1 |
