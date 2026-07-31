# Development Task Backlog

> Status legend: `todo` | `doing` | `done` | `blocked` | `deferred`  
> Updated: 2026-07-31 — autonomous full implementation pass

---

## M0 — Bootstrap

| ID | Priority | Status | Task |
| -- | -------- | ------ | ---- |
| M0-T01–T12 | P0/P1 | **done** | Scaffold, git, `.ai`, Flutter platforms, CI, Review+D2D |

---

## M1 — Local core

| ID | Priority | Status | Task |
| -- | -------- | ------ | ---- |
| M1-T01–T14 | P0/P1 | **done** | Workspace, Drift, CRUD, UI, tags, theme, history, tests, D2D |

---

## M2 — Memos API & auth

| ID | Priority | Status | Task |
| -- | -------- | ------ | ---- |
| M2-T01–T12 | P0/P1 | **done** | Server WS, login, Dio, DTO, pull, logout, TLS toggle, tests |

---

## M3 — Sync Engine

| ID | Priority | Status | Task |
| -- | -------- | ------ | ---- |
| M3-T01–T12 | P0/P1 | **done** | Queue, coalesce, worker, push/pull, LWW, AuthGate, status UX, tests |

---

## M4 — Search & attachments

| ID | Priority | Status | Task |
| -- | -------- | ------ | ---- |
| M4-T01–T09 | P0/P1 | **done** | FTS search, filters, local attachments, size warn |

---

## M5 — Desktop polish

| ID | Priority | Status | Task |
| -- | -------- | ------ | ---- |
| M5-T01 | P1 | **done** | Window size/position persist |
| M5-T02 | P1 | **done** | Shortcuts new/sync |
| M5-T03 | P2 | **deferred** | Global hotkey |
| M5-T04 | P3 | **deferred** | System tray |
| M5-T05–T06 | P1 | **done** | Density via adaptive UI + D2D |

---

## M6 — Android polish

| ID | Priority | Status | Task |
| -- | -------- | ------ | ---- |
| M6-T01 | P1 | **deferred** | Share intent native wiring (follow-up) |
| M6-T02–T03 | P1 | **done** | Navigation + list structure |
| M6-T04–T05 | P2/P3 | **deferred** | Notifications / widget |
| M6-T06 | P1 | **done** | D2D noted residual |

---

## M7 — Hardening

| ID | Priority | Status | Task |
| -- | -------- | ------ | ---- |
| M7-T01–T03 | P1 | **done** | History UI, sync tests, analyze/test green |
| M7-T04 | P2 | **deferred** | SQLCipher spike → future ADR |
| M7-T05–T07 | P1 | **done** | Secure token store, MVP script in D2D |

---

## M8+ — Post-V1

| ID | Status | Task |
| -- | ------ | ---- |
| M8-* | deferred | AI, cloud adapters, iOS polish, relations/comments |

---

## Active focus

**V1 code complete.** Next recommended work:

1. Point at a real Memos instance and harden auth/update paths for that version
2. Wire attachment binary upload API
3. Android share intent
4. Optional: tray / global hotkey / SQLCipher

---

## Verification (2026-07-31)

```text
flutter analyze → No issues found
flutter test    → All tests passed (12)
```
