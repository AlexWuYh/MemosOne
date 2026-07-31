# Development Standards — Memos One

> Version: 1.0  
> Status: Normative  
> Applies to: humans and AI agents

---

## 1. Purpose

Ensure the project grows in **measurable milestones**, each ending with a rigorous **Review** and **D2D (Design-to-Done)** gate so quality, docs, and offline-first principles do not drift.

---

## 2. Core process: Milestone Development Mode

We do **not** develop as an endless feature stream. Work is organized as:

```
Milestone (Mx)
  → Plan (scope locked)
  → Implement tasks (small, vertical slices)
  → Continuous self-check
  → Milestone Review
  → D2D gate
  → Tag / release note (even internal)
  → Next milestone
```

### 2.1 Milestone properties

| Property | Rule |
| -------- | ---- |
| Duration | Prefer 3–10 focused working days of scope (size by outcome, not calendar dogma) |
| Scope | Written in `tasks/milestones.md` + checklist in `tasks/backlog.md` |
| Exit | **Review + D2D both pass** |
| Change control | Scope adds require explicit milestone amendment |

### 2.2 Task sizing

- One task = one reviewable outcome (ideally ≤ 1 day)
- Tasks link to acceptance criteria
- Prefer vertical slices (UI + domain + data) over pure horizontal layers when delivering user value
- Infra-only tasks allowed in M0/M2 foundations

### 2.3 Branching (lightweight)

| Branch | Use |
| ------ | --- |
| `main` | Always D2D-green for completed milestones |
| `milestone/mX-short-name` | Optional integration branch |
| `feat/*`, `fix/*`, `chore/*` | Task branches |

Commit style: Conventional Commits preferred:

```text
feat(memo): local create path writes sqlite first
fix(sync): coalesce update tasks
docs(ai): update sync-spec LWW rules
```

---

## 3. Definition of Ready (DoR) — before starting a task

A task is ready when:

1. Linked to a milestone
2. Acceptance criteria written
3. Touched architecture docs identified (if any)
4. No unresolved blocker in dependencies
5. Offline-first impact considered (does this require network?)

Template: [../templates/task-card.md](../templates/task-card.md)

---

## 4. Definition of Done (DoD) — for every task

A task is done only if:

1. Code meets [coding-conventions.md](./coding-conventions.md)
2. Offline-first rules not violated
3. Tests added/updated when logic is non-trivial
4. `dart analyze` / project lints clean for touched areas
5. No secrets committed
6. Relevant `.ai` docs updated if behavior/architecture changed
7. Self-reviewed diff (or peer review when available)

---

## 5. Milestone Review

At the end of each milestone, complete a **Review** before D2D.

### 5.1 Goals of Review

- Verify scope completed vs promised
- Find architectural drift early
- Catch offline-first / security regressions
- Decide: pass / pass with follow-ups / fail (re-open milestone)

### 5.2 Review checklist (minimum)

| Area | Questions |
| ---- | --------- |
| Scope | All milestone backlog items Done or explicitly deferred? |
| Architecture | Layers respected? Any Widget→DB/HTTP? |
| Sync / data | Local-first writes? Queue correct? |
| UX | Error/empty/loading/offline states? |
| Tests | Critical paths covered? |
| Docs | `.ai` updated? |
| Debt | New debt listed with owner milestone? |

Use form: [../templates/milestone-review.md](../templates/milestone-review.md)

### 5.3 Review outputs

1. Filled review document under `.ai/tasks/reviews/mX-review.md`
2. List of **must-fix** vs **follow-up**
3. Go / No-Go for D2D

---

## 6. D2D — Design-to-Done

**D2D** is the milestone exit gate: prove that **what we designed is what we delivered**, end-to-end.

### 6.1 Meaning

| Letter | Meaning |
| ------ | ------- |
| **D**esign | Milestone acceptance criteria + architecture constraints |
| **to** | Traceability |
| **D**one | Runnable demo + DoD + docs + no P0 defects |

D2D is **not** “code merged”. D2D is **demonstrably done**.

### 6.2 D2D steps (mandatory)

1. **Traceability** — Each milestone acceptance criterion maps to evidence (test, screenshot note, or script).
2. **E2E happy path** — Run the milestone scripted demo (manual OK in early M; automate later).
3. **Offline / failure path** — At least one negative path (airplane mode, invalid token, etc.) when relevant.
4. **Quality bar** — analyze + tests green.
5. **Doc bar** — vision/architecture/tasks reflect reality.
6. **Sign-off** — record pass in `.ai/tasks/reviews/mX-d2d.md` using [../templates/d2d-checklist.md](../templates/d2d-checklist.md).

### 6.3 D2D failure

If D2D fails:

- Milestone stays open
- Create fix tasks with priority P0/P1
- No start of next milestone’s **scope expansion** (hotfix only)

### 6.4 D2D artifacts

```text
.ai/tasks/reviews/
  m0-review.md
  m0-d2d.md
  m1-review.md
  m1-d2d.md
  ...
```

---

## 7. Continuous practices (inside a milestone)

### 7.1 Daily / per-session loop

```
Pick task → implement → self-check DoD → mark done → small commit
```

### 7.2 AI agent rules

1. Read `.ai/README.md` then milestone + task before coding
2. Do not expand milestone scope silently
3. Prefer updating docs in same change set as architecture shifts
4. After finishing a milestone’s last task, **stop and run Review + D2D templates** (do not auto-jump to next M)

### 7.3 Quality gates (local)

Before claiming task done:

```bash
# when Flutter SDK available
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

M0 may only have partial toolchain until Flutter is installed; document gaps in D2D.

---

## 8. Documentation standards

| Doc type | Location | When to update |
| -------- | -------- | -------------- |
| Vision / scope | `.ai/product/` | Scope change |
| Architecture | `.ai/architecture/` | Structural / protocol change |
| ADR | `.ai/decisions/` | Significant decision |
| Tasks | `.ai/tasks/` | Every planning change |
| Reviews / D2D | `.ai/tasks/reviews/` | End of milestone |

**All AI-oriented docs live under `.ai/`.** Root `README.md` stays human onboarding and points here.

---

## 9. Priority labels

| Priority | Meaning |
| -------- | ------- |
| P0 | Blocks milestone D2D / data loss / security |
| P1 | Required for milestone acceptance |
| P2 | Should have; can slip with note |
| P3 | Nice to have / next milestone candidate |

---

## 10. Risk & debt log

Each milestone review must update:

- New technical debt items → backlog with target milestone
- Risks → owner + mitigation

Do not hide debt in chat history only.

---

## 11. Release tagging

When a milestone D2D passes:

```text
git tag -a mX-d2d -m "Milestone X D2D passed"
```

Optional pre-release app version bump in `pubspec.yaml` when shipping builds.

---

## 12. Summary diagram

```
┌─────────────┐
│  Milestone  │
│   planned   │
└──────┬──────┘
       ▼
┌─────────────┐
│   Tasks     │  each: DoR → code → DoD
└──────┬──────┘
       ▼
┌─────────────┐
│   Review    │  architecture, scope, debt
└──────┬──────┘
       ▼
┌─────────────┐
│    D2D      │  demo + evidence + sign-off
└──────┬──────┘
       ▼
┌─────────────┐
│  Tag main   │  start next milestone
└─────────────┘
```
