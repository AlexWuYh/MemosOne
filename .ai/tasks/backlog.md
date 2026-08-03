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

1. Live sync D2D after force-drain / orphan requeue fix  
2. Attachment remote upload (FIX-18) — web parity gap  
3. Android share intent (FIX-19 family)

## Web parity (Memos web → app)

| Web capability | App | Notes |
| -------------- | --- | ----- |
| Memo CRUD + Markdown | Yes | Edit stays until user taps 预览 |
| Visibility PRIVATE/PROTECTED/PUBLIC | Yes | |
| Pin / Archive | Yes | |
| Public share URL `/m/{id}` | Yes | Header bar on PUBLIC |
| Explore public timeline | Yes | Feed-style cards + full view |
| Search (local FTS) | Yes | |
| Tags filter | Yes | Chips in list + tag tap in detail |
| Calendar / heatmap | Yes | |
| Sync status + force sync | Yes | Force drain + orphan requeue |
| Attachments on Memos workspace | Partial | Local-only; remote upload deferred |
| Comments / reactions / relations | No | Unsuitable for offline-first MVP; server social |
| Shortcuts service | No | Deferred |
| Instance admin / SSO | No | Not a client goal |

---

## Verification

```text
flutter analyze
flutter test
```
