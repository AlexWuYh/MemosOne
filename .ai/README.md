# Memos One — AI Documentation Index

> **All documentation intended for AI (and humans) lives under `.ai/`.**
>
> Agents must read this index first, then follow links for the task at hand.

## Project in one sentence

**Memos One** is an **Offline First** native cross-platform client for [usememos/memos](https://github.com/usememos/memos). Local SQLite is the source of truth; Memos Server is a sync peer.

## Read order (onboarding)

| Order | Doc | When |
| ----- | --- | ---- |
| 1 | [product/vision.md](./product/vision.md) | Product goals, MVP scope, non-goals |
| 2 | [architecture/architecture.md](./architecture/architecture.md) | System architecture (V1.1) |
| 3 | [architecture/memos-compatibility.md](./architecture/memos-compatibility.md) | Official API mapping |
| 4 | [architecture/sync-spec.md](./architecture/sync-spec.md) | Sync protocol & state machine |
| 5 | [architecture/data-model.md](./architecture/data-model.md) | Local schema & ID strategy |
| 6 | [standards/development-standards.md](./standards/development-standards.md) | Milestones, Review, D2D |
| 7 | [standards/coding-conventions.md](./standards/coding-conventions.md) | Code rules for AI/humans |
| 8 | [tasks/milestones.md](./tasks/milestones.md) | Milestone roadmap |
| 9 | [tasks/backlog.md](./tasks/backlog.md) | Executable task checklist |

## Historical / draft

| Doc | Note |
| --- | ---- |
| [architecture/architecture-v1.0-draft.md](./architecture/architecture-v1.0-draft.md) | Original draft; superseded by V1.1 docs above |

## Templates

| Template | Use |
| -------- | --- |
| [templates/milestone-review.md](./templates/milestone-review.md) | End-of-milestone Review form |
| [templates/d2d-checklist.md](./templates/d2d-checklist.md) | Design-to-Done checklist |
| [templates/task-card.md](./templates/task-card.md) | Single task card format |

## Decisions (ADR)

| Doc | Note |
| --- | ---- |
| [decisions/README.md](./decisions/README.md) | ADR index and naming |
| [decisions/0001-offline-first-local-sot.md](./decisions/0001-offline-first-local-sot.md) | Local is source of truth |
| [decisions/0002-flutter-stack.md](./decisions/0002-flutter-stack.md) | Flutter + Drift + Riverpod |
| [decisions/0003-mvp-scope.md](./decisions/0003-mvp-scope.md) | V1 MVP boundaries |

## Agent hard rules (summary)

1. **UI never talks to DB/HTTP** — only Repository / UseCase.
2. **Write local first**, then enqueue sync — never wait for network to confirm UX.
3. **Do not expand scope** beyond current milestone without updating `tasks/` and vision.
4. **After each milestone**: Review + D2D (see development standards).
5. Prefer changing docs under `.ai/` when architecture decisions change; keep code and docs in sync.

## Repo map

```
.ai/                 ← AI-readable project brain (this tree)
lib/                 ← Flutter application source
test/                ← Unit / widget tests
docs/                ← Optional human-facing docs (links to .ai when needed)
scripts/             ← Dev helper scripts
```
