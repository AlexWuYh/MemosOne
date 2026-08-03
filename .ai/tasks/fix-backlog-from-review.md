# Fix backlog — from Full Review (2026-08-03)

> Implementation pass: 2026-08-03

| ID | Pri | Status | Title |
| -- | --- | ------ | ----- |
| FIX-01 | P0 | **done** | Autosave cancelable debounce; bind via listenManual |
| FIX-02 | P0 | **done** | Pull remote-delete reconcile via `seen` + listServerBound |
| FIX-03 | P0 | **done** | Full pull only on force / first sync / 30m interval |
| FIX-04 | P0 | **done** | Never-synced delete: cancelAllForEntity + hardDelete |
| FIX-05 | P1 | **done** | Visibility picker in editor |
| FIX-06 | P1 | **done** | Sync badge last pull + dead count; app bar last sync |
| FIX-07 | P1 | **done** | ADR 0004 single-DB multi-workspace |
| FIX-08 | P1 | **done** | SyncMemoGateway port for SyncWorker |
| FIX-09 | P1 | **done** | Hide attach on Memos workspace |
| FIX-10 | P1 | **done** | Re-grade backlog honesty |
| FIX-11 | P1 | **done** | Reject cookie-as-Bearer login |
| FIX-12 | P1 | **done** | contentHash on create/update |
| FIX-13 | P2 | **done** | Tests: pull policy + remote-delete reconcile |
| FIX-14 | P2 | **done** | Debounced search + Ctrl/Cmd+F |
| FIX-15 | P2 | **done** | Medium breakpoint workspace rail strip |
| FIX-16 | P2 | **done** | Markdown migration note in README |
| FIX-17 | P3 | **deferred** | Live Memos Docker D2D |
| FIX-18 | P3 | **deferred** | Attachment remote upload |
| FIX-19 | P3 | **deferred** | Tray / hotkey / SQLCipher / share intent |

## Exit criteria

- [x] P0/P1/P2 implemented
- [x] `flutter analyze` clean
- [x] `flutter test` green (18 tests)

