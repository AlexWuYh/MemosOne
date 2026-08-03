# Memos One — Full Project Review

| Field | Value |
| ----- | ----- |
| Date | 2026-08-03 |
| Scope | Product + Architecture + Code + Process (whole codebase, not a single PR) |
| Codebase | ~10k LOC Dart (`lib/`), 12 tests, analyze clean |
| Verdict | **Strong foundation; not yet V1-ready as a Memos client** |

---

## 0. Executive summary

Memos One has a **clear product thesis** (Offline First, Local SoT, Memos as sync peer), a **coherent architecture document set** under `.ai/`, and an implementation that **mostly follows local-first CRUD** with a real SyncQueue + Worker skeleton.

However, several gaps mean the project currently behaves more like a **polished local notes shell with a best-effort Memos adapter** than a **trustworthy Memos ecosystem client**:

1. **No proven end-to-end sync against a real Memos instance** (auth/update multi-path is speculative).
2. **Pull reconcile is incomplete** (remote deletes ignored; `seen` unused).
3. **Architecture drift**: single shared SQLite vs per-workspace DB; thin/missing Application layer; SyncWorker couples to concrete `MemoRepositoryImpl`.
4. **Product trust UX incomplete** (visibility, last-sync time, conflict awareness, attachment remote sync).
5. **Test depth lags claimed milestone completion** (queue/LWW unit tests yes; worker/API integration no).

**Recommended stance:** Treat current tree as **M1 solid + M2–M3 alpha**. Do not market as V1 until live-instance D2D and P0 sync bugs are closed.

---

## 1. Product-level review

### 1.1 Positioning & scope

| Aspect | Assessment |
| ------ | ---------- |
| Vision clarity | **Excellent** — “not a new notes app that happens to sync” is correct |
| MVP non-goals | **Good** — Cloud/AI/social correctly deferred |
| Scope honesty vs backlog | **Weak** — backlog marks M2–M7 largely **done**, but residuals admit live API, attachment upload, share intent still open |

**Finding P-1 (High) — Milestone “done” overstates product readiness**

Backlog claims M2–M7 done and “V1 code complete,” while Active focus still lists real-instance hardening and attachment upload. This misleads agents and humans about ship state.

**Suggestion:** Split statuses into `code-complete` vs `product-verified`. Keep V1 closed only after live D2D against a pinned Memos version.

### 1.2 MVP success criteria (vision) vs reality

| Criterion | Status | Notes |
| --------- | ------ | ----- |
| Local workspace full CRUD + Markdown | **Met (code)** | Create/edit/delete/pin/archive, preview, tags |
| Memos login + first full sync | **Unverified** | UI + multi-endpoint login exist; no contract test / recorded instance matrix |
| Offline edit → online push/pull LWW | **Partial** | Queue + LWW logic present; pull bugs; no E2E |
| FTS search | **Partial** | FTS5 table + fallback LIKE; scale to 100k unmeasured |
| Clear sync status | **Partial** | Badge exists; last success time / per-item error UX thin |
| Win / macOS / Android | **Scaffolded** | Platforms generated; Android daily-driver polish deferred |

### 1.3 Trust model (Offline First products live or die here)

Vision requires: connectivity state, last successful sync, dirty/error visibility, global retry, no silent data loss.

| Trust signal | Present? |
| ------------ | -------- |
| Offline / syncing / error badge | Yes (rail) |
| Manual Sync now | Yes |
| Per-item dirty (“pending sync”) | Yes (list subtitle) |
| Last successful sync timestamp | Weak / not prominent |
| Dead letter surface | Settings only |
| LWW loss → history | Code path yes; user discovery low |
| Conflict messaging | No user-facing “remote won” toast |

**Finding P-2 (High) — Trust UX is under-built for an Offline First promise**

Users will not trust silent LWW overwrites. History exists but is buried behind a toolbar icon.

**Suggestion:** After sync cycle, surface “N items updated from server / M local changes kept”; link to history when LWW lost.

### 1.4 Memos-as-ecosystem product fit

| Gap | Impact |
| --- | ------ |
| No UI for **visibility** (PRIVATE/PROTECTED/PUBLIC) | Core Memos concept missing in editor |
| No creator / resource name display | Harder to debug multi-device |
| Attachments not server-synced | Incomplete vs typical Memos usage |
| No share / public link (ok for V1 non-goal) | Fine if explicit |
| Branding is generic Material notes | Weak “this is a Memos client” recognition |

**Finding P-3 (Medium) — Domain model knows Memos fields the product does not expose**

Visibility is first-class in entity/API but invisible in UI → default always private, round-trip incomplete for power users.

### 1.5 UX / interaction quality

**Strengths**

- Onboarding empty state is clear (local vs connect server).
- Responsive shell: 3-pane / medium / mobile list→detail.
- Autosave path aims for offline-first feel.
- Filters: Active / Pinned / Archived.

**Weaknesses**

- **Autosave race** (see Code C-1): switching memos during debounce can write wrong content.
- New memo starts empty with no placeholder guidance beyond hint.
- Search is list-header only; desktop Cmd+F not wired to focus.
- Medium layout drops workspace rail (workspaces only via other breakpoints/onboarding).
- No progress for first large pull.

**Finding P-4 (Medium) — Desktop multi-workspace discoverability regresses at medium width**

Between 600–900px, workspace rail disappears without an obvious entry equivalent to mobile’s bottom sheet.

### 1.6 Product prioritization recommendation

| Priority | Outcome |
| -------- | ------- |
| P0 | Live Memos D2D + fix pull delete reconcile + autosave race |
| P1 | Visibility control, last-sync time, first-sync progress |
| P1 | Attachment remote pipeline or hide attach for Memos WS |
| P2 | Share intent, tray, hotkeys |
| P3 | AI / cloud adapters |

---

## 2. Architecture-level review

### 2.1 Document quality

`.ai/` is a major asset:

- vision, architecture V1.1, sync-spec, data-model, compatibility matrix, ADRs, standards (Review + D2D)

This is **above average** for an early Flutter client and suitable for AI-assisted development.

**Finding A-1 (Medium) — Docs and code have drifted without ADR updates**

Notable drifts:

| Spec | Implementation |
| ---- | -------------- |
| Per-workspace SQLite file as active DB | **Single** `memos_one.sqlite`; `databasePath` stored but not opened as SoT |
| Application layer UseCases | UI → Repository via Riverpod; almost no application/ use cases |
| Incremental pull cursor | Cursor table written; pull is full list pagination every cycle |
| Remote delete when clean local | `seen` set populated, **never used** |
| Attachment sync M4 | Local only |

**Suggestion:** Either fix code to match spec or amend architecture + ADR (single DB multi-tenant is a valid V1 choice if documented).

### 2.2 Layering & dependency rules

| Rule | Status |
| ---- | ------ |
| UI ↛ Dio / Drift | **Pass** (no feature imports of network/db) |
| Domain pure | **Pass** |
| Repository as data entry | **Mostly pass** |
| Feature isolation | **Partial** — few features; presentation imports shared providers OK |
| Application orchestration | **Thin** — business orchestration lives in widgets + SyncWorker |

**Finding A-2 (Medium) — Clean Architecture is “ports present, application layer hollow”**

Presentation calls `memoRepositoryProvider` / `authRepositoryProvider` directly. Acceptable for early MVP, but:

- Harder to test multi-step flows without widgets
- Sync start/login side effects scatter across rail, dialogs, providers

**Suggestion:** Introduce thin use cases: `CreateMemo`, `SaveMemo`, `LoginToWorkspace`, `RunSyncCycle`.

### 2.3 Sync architecture

**Strengths**

- Durable queue + coalesce rules align with sync-spec intent.
- AuthGate pause on 401 is correct product/architecture choice.
- ConflictResolver pure unit + history on remote win.
- Command path is local-first in `MemoRepositoryImpl`.

**Critical defects**

**Finding A-3 (P0 / Bug) — Pull does not reconcile remote deletions**

In `sync_worker.dart` `_pull`, `seen` collects remote names but nothing deletes local rows missing from remote when local is clean. Spec requires remote-delete convergence. Users will keep “ghost” memos forever after server delete.

**Finding A-4 (P0 / Bug-risk) — Every sync cycle full-pulls (`forcePull \|\| true`)**

```dart
if (forcePull || true) {
  await _pull(workspace);
}
```

Always full pagination. Correctness-ish for small libraries; **battery/network disaster** at scale; cursor table is cosmetic.

**Finding A-5 (High) — SyncWorker depends on concrete `MemoRepositoryImpl` + raw Drift**

Worker bypasses the repository port for workspace updates and direct memo selects. Violates dependency inversion and makes substitution/testing harder.

**Finding A-6 (High) — Create idempotency residual risk remains open**

Network loss after successful create before binding `serverName` can duplicate memos. Spec called this out; implementation does not implement “pull before recreate” mitigation.

### 2.4 Identity & multi-workspace isolation

- `localId` + `serverName` strategy is correct (V1.1 improvement over draft triple IDs).
- Logical isolation via `workspaceId` works for queries.
- Physical isolation via separate DB files is **not enforced** → workspace delete can wipe rows in shared DB (implemented) but corruption/backup story differs from “delete one file”.

**Finding A-7 (Medium) — `databasePath` is misleading API surface**

Creates expectation of per-WS files; runtime uses app-global Drift DB.

### 2.5 Security architecture

| Control | Status |
| ------- | ------ |
| Token in secure storage | Yes |
| Token not in SQLite | Yes (good) |
| Allow insecure TLS | Explicit toggle (good) with risk copy |
| Log scrubbing of Authorization | Partial (status codes logged; need guarantee body never logs token) |
| SQLCipher | Deferred (acceptable if documented) |
| Logout clears token | Yes |

**Finding A-8 (Medium) — Cookie-string-as-token fallback is insecure/fragile**

Login may store `set-cookie` join as “token” and send as Bearer. Unlikely to work; may leak cookie material into secure storage semantics incorrectly.

### 2.6 Extensibility

- Cloud Storage Adapter: **not stubbed as SPI** despite architecture reservation.
- AI feature folders exist as empty placeholders — fine.
- API multi-path login shows awareness of version skew but without a version matrix runtime check → **compatibility matrix not enforced in code**.

---

## 3. Code-level review

### 3.1 Correctness bugs

#### C-1 (P0) — Autosave can write content to the wrong memo

`memo_detail_panel.dart` schedules `Future.delayed(400ms)` on each keystroke without cancellation. If user switches selection, delayed closure still holds old `memo` and may `update(oldId, newControllerText)` or race with `_bind`.

**Fix:** Use debounce `Timer` cancelled on dispose/switch; capture `localId` and abort if selection changed; prefer `ref.listen` + explicit save.

#### C-2 (P0) — Remote delete not applied (see A-3)

#### C-3 (High) — Soft-delete path for never-synced memos still enqueues delete after hard delete

When `sync && serverName == null`, code hard-deletes then enqueues delete. Coalesce usually cancels create+delete, but orphan delete tasks may run no-op. Messy; simplify to cancel queue only.

#### C-4 (Medium) — Side effect in `build()` (`_bind(memo)`)

Sets controller text during build → can fight framework rebuild rules and cursor position.

#### C-5 (Medium) — Search FTS query builder quotes tokens naively

Special characters / CJK edge cases fall back to LIKE (caught), but MATCH errors swallowed broadly.

### 3.2 Reliability / performance

| Issue | Severity |
| ----- | -------- |
| Full pull every 5s when online | High |
| `watchAll` N+1 tag queries per row | Medium at scale |
| No list virtualization tuning for 10k+ | Medium (ListView.builder OK baseline) |
| Sync status always “idle” after cycle even if dead tasks remain | Low/Med |

### 3.3 API client quality

**Strengths:** timeouts, multi-login attempts, dual update body shapes, 404 delete = success.

**Weaknesses:**

- No OpenAPI/proto-generated models → drift from upstream guaranteed.
- Update mask / field names may not match current memos proto (`state` vs row status).
- List filter does not force “creator = me” (compatibility doc intent).
- No structured version negotiation after login.

### 3.4 UI structure / maintainability

- `providers.dart` is a god-module (DI + UI state + streams) — works short-term.
- Feature folders lack `application/` implementations; many empty `.gitkeep` layers add noise without benefit.
- Duplicate concepts: `memoRepositoryProvider` vs `memoRepositoryImplProvider`.

### 3.5 Testing

| Area | Coverage |
| ---- | -------- |
| Tag parse | Yes |
| Conflict LWW | Yes |
| Queue coalesce | Yes |
| Memo local CRUD | Yes (in-memory Drift) |
| DTO map | Yes |
| Widget smoke | Yes |
| SyncWorker push/pull | **No** |
| Auth/API with mock Dio | **No** (claimed in backlog M2-T11) |
| Autosave race | **No** |
| Remote delete | **No** |

**Finding C-6 (High) — Quality bar is “analyze green,” not “sync correct”**

12 tests are valuable but leave the highest-risk module (SyncWorker) untested.

### 3.6 Tooling / repo hygiene

- CI generates Drift — good.
- `*.g.dart` ignored — clone requires build_runner (documented).
- Linux platform present while vision says Linux not V1 — harmless.
- `flutter_markdown` discontinued upstream — plan migration.

---

## 4. Process & documentation review

| Practice | Assessment |
| -------- | ---------- |
| `.ai` as single AI knowledge root | Excellent |
| Milestone + Review + D2D templates | Excellent design |
| Actual D2D rigor | Weak for M2–M7 (combined doc admits optional live instance) |
| ADR discipline | Good start; missing drift ADRs |
| Backlog accuracy | Over-complete; residuals under-weighted |

**Finding PROC-1 (Medium) — D2D for sync milestones must require live or recorded HTTP fixtures**

Without WireMock/VCR or a dockerized Memos, “M3 D2D pass” is not a real gate.

---

## 5. Scorecard

| Dimension | Score (1–5) | Comment |
| --------- | ----------- | ------- |
| Product vision | 5.0 | Clear, differentiated |
| MVP scope control (docs) | 4.5 | Docs good; execution labeled too complete |
| Product completeness vs MVP | 2.5 | Local strong; Memos trust incomplete |
| Architecture docs | 4.5 | Among project strengths |
| Architecture–code alignment | 2.5 | Material drifts + pull holes |
| Offline-first discipline | 4.0 | Local write path correct |
| Sync correctness | 2.0 | Coalesce good; reconcile incomplete |
| Security baseline | 3.5 | Secure storage good; TLS/cookie caveats |
| Code quality / structure | 3.0 | Clean enough; races & coupling |
| Test strategy | 2.5 | Unit islands, no integration core |
| UX polish | 3.0 | Usable shell; trust/density gaps |
| Ship readiness (V1) | 2.0 | Not yet |

**Overall: 3.1 / 5 — promising alpha, not a finished V1 Memos client.**

---

## 6. Priority action list

### P0 — correctness / data trust

1. Fix autosave race (C-1).
2. Implement remote-delete reconcile using `seen` (A-3).
3. Stop unconditional full pull; honor incremental/full schedule (A-4).
4. Run D2D against a **pinned** Memos docker image; freeze API mapping.

### P1 — product / architecture honesty

5. Visibility picker in editor.
6. Show last sync time + dead-count badge more prominently.
7. ADR: single-DB multi-workspace (or implement multi-file).
8. SyncWorker depends on ports only; add worker unit tests with fakes.
9. Either ship attachment remote sync or hide attach on Memos workspaces.
10. Re-grade backlog statuses; reopen M2/M3 until product-verified.

### P2 — quality

11. Mock Dio auth + list + create integration tests.
12. Debounced search + Cmd/Ctrl+F focus.
13. Medium breakpoint workspace entry.
14. Replace discontinued markdown package plan.

### P3 — later

15. Tray / global hotkey / SQLCipher / share intent / AI.

---

## 7. What to keep (do not throw away)

1. **Local-first write protocol** in `MemoRepositoryImpl` — right core bet.
2. **SyncQueue coalesce rules** — solid and tested.
3. **ConflictResolver + memo_history** — right safety net direction.
4. **`.ai` documentation system + standards** — rare and valuable.
5. **Secure token storage separation** — correct security boundary.
6. **Responsive shell skeleton** — good base for desktop + mobile.

---

## 8. Closing judgment

If the goal is **“ship a delightful offline notes app”**, you are closer than the sync story suggests — local path is the strongest part of the system.

If the goal is **“ship a first-class Offline First Memos client”** (as vision states), the project still needs a focused **sync hardening milestone** with live verification, not more feature surface (AI/cloud/tray).

**Recommended next milestone (M3.1 Hardening):** P0 list only, explicit product-verified D2D, no new features.
