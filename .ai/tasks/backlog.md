# Development Task Backlog

> Updated: 2026-08-03 after full review + fix pass  
> Fix items: [fix-backlog-from-review.md](./fix-backlog-from-review.md)

## Product readiness (honest)

| Area | Status | Notes |
| ---- | ------ | ----- |
| M0 Bootstrap | **product-verified** | Scaffold, CI, docs |
| M1 Local core | **product-verified** (code + unit) | Offline CRUD |
| M2 Memos API & auth | **code-complete / not product-verified** | Needs live instance D2D |
| M3 Sync Engine | **code-complete / hardening in progress** | Queue+LWW+delete reconcile; live D2D open |
| M4 Search & attachments | **partial** | FTS local OK; Memos attach hidden until remote upload |
| M5–M7 polish | **partial** | Window/shortcuts/history; tray/share deferred |

**V1 is NOT closed** until live Memos D2D (FIX-17).

---

## Active focus

1. Optional: Docker Memos live D2D (FIX-17)  
2. Attachment remote upload (FIX-18)  
3. Android share intent (FIX-19 family)

---

## Verification

```text
flutter analyze
flutter test
```
