# Sync Engine Specification

> Version: 1.1  
> Status: Normative for V1  
> Depends on: [data-model.md](./data-model.md), [memos-compatibility.md](./memos-compatibility.md)

---

## 1. Goals

1. Local mutations never block on network.
2. Eventually consistent with Memos server for the current user.
3. Safe retries (minimize duplicates).
4. Deterministic conflict policy (LWW) with no silent queue freezes.
5. Observable status for UX and debugging.

Non-goals (V1):

- CRDT / three-way merge
- Real-time multi-cursor
- Partial field-level merge UI

---

## 2. Components

```
Repository (command path)
    │ enqueue
    ▼
SyncTask table (durable queue)
    │
    ▼
SyncWorker ──AuthGate──► Remote API
    │                         │
    │ apply results           │ pull pages
    ▼                         ▼
Local SQLite ◄────────── PullApplier
    │
    ▼
ConflictResolver (LWW)
```

| Component | Responsibility |
| --------- | -------------- |
| **SyncQueue** | Persist tasks; unique constraints; status |
| **SyncWorker** | Schedule push/pull; backoff; concurrency limits |
| **Puller** | Fetch remote changes into local |
| **ConflictResolver** | Decide winner on concurrent edits |
| **AuthGate** | On 401, pause and request re-auth |

---

## 3. SyncTask model

```text
SyncTask
  id              TEXT PK
  workspaceId     TEXT
  entityType      ENUM memo | attachment | ...
  entityLocalId   TEXT
  action          ENUM create | update | delete
  payloadJson     TEXT?          # optional snapshot for debug
  status          ENUM pending | running | failed | dead
  retryCount      INT
  nextAttemptAt   DATETIME
  lastError       TEXT?
  createdAt       DATETIME
  updatedAt       DATETIME
```

### 3.1 Enqueue rules

| User op | Local DB | Queue |
| ------- | -------- | ----- |
| Create | insert memo `dirty=true`, `syncStatus=pending` | `create` |
| Update | update fields, `dirty=true` | coalesce to single `update` (or `create` if never pushed) |
| Delete | soft-delete, `dirty=true` | `delete` (or drop pending `create` if never pushed) |

**Coalescing (mandatory):**

- Multiple updates on same entity → one `update` task
- `create` then `delete` before push → cancel both; hard-delete local if never on server
- `create` then `update` → keep `create` with latest payload

### 3.2 Idempotency

| Action | Strategy |
| ------ | -------- |
| create | If `serverName` already set, convert task to `update` |
| create retry | If server returns success or identifiable duplicate, bind `serverName` and complete |
| update | PATCH by `serverName`; if 404 → treat as recreate or drop per policy below |
| delete | DELETE by `serverName`; 404 = success |

V1 does **not** send client UUIDs as server IDs. Duplicate creates on repeated failure without binding are a known residual risk; mitigate by:

- Not re-creating when a prior response may have succeeded (network loss after 200): on uncertainty, **pull by content hash / recent list** before new create (best-effort in M3; harden in M7)

---

## 4. Entity sync status

```text
clean ──edit──► dirty ──worker──► syncing ──ok──► clean
                      │              │
                      │              └─fail──► error ──retry/backoff──► dirty/syncing
                      │
                      └─offline remains dirty
```

| Status | Meaning |
| ------ | ------- |
| `clean` | Local matches last known server (or local-only workspace) |
| `dirty` | Local ahead; queued or about to queue |
| `syncing` | Worker holds task |
| `error` | Terminal for now; retry scheduled or user action needed |
| `conflict` | Reserved; V1 resolves automatically via LWW then leaves `dirty` or `clean` |

Local-only workspace: always treat as `clean` after write (no queue).

---

## 5. Push pipeline

```
every tick (event + interval):
  if workspace != memos: return
  if AuthGate.blocked: return
  if !connectivity: return

  task = next pending where nextAttemptAt <= now
  mark running
  switch action:
    create → POST memo → bind serverName → clear dirty → delete task
    update → PATCH memo → update updatedAtServer → clear dirty → delete task
    delete → DELETE → hard-delete or tombstone finalize → delete task
  on failure:
    retryCount++
    status = failed/pending
    nextAttemptAt = now + backoff(retryCount)
    lastError = message
    if retryCount > N: status = dead; surface to UI
```

### 5.1 Backoff

```
retryCount: 0,1,2,3,4,5,6+
delay:      2s,5s,15s,30s,60s,300s,300s (cap)
```

Jitter: ±20% recommended.

### 5.2 Concurrency

- V1: **1 push task per workspace** at a time (simple ordering)
- Pull can run when push queue empty, or interleaved with care (no write races): prefer **serialize push then pull** per cycle

---

## 6. Pull pipeline

### 6.1 First sync (workspace bind)

1. Authenticate; store token.
2. Full `ListMemos` pagination for current user.
3. Upsert all into SQLite with `serverName`, `syncStatus=clean`, `dirty=false`.
4. Set `workspace.initialSyncCompleted=true`.
5. Record `lastPullAt` + high-water `updatedAtServer` cursor.

### 6.2 Incremental pull

When possible:

```
list memos where update_time > lastPullCursor
```

Else:

- Periodic full reconcile (e.g. every N hours or manual sync)
- Compare by `serverName`:
  - Remote newer & local `clean` → overwrite local content fields
  - Remote newer & local `dirty` → **ConflictResolver**
  - Local has `serverName` missing remotely → remote deleted: if local `clean`, soft/hard delete local; if `dirty`, keep local and re-queue create

### 6.3 Pull never drops dirty blindly

If local `dirty==true`, pull **must not** overwrite without ConflictResolver.

---

## 7. Conflict resolution (V1 LWW)

### 7.1 Comparable time

Define `effectiveRemote = memo.update_time` from server.  
Define `effectiveLocal = max(updatedAtLocal, lastSuccessfulPushLocalTime?)`.

**Rules:**

| Condition | Winner |
| --------- | ------ |
| local dirty AND remote unchanged since last pull | local (push) |
| local clean AND remote newer | remote (apply pull) |
| local dirty AND remote newer than `updatedAtServer` we based on | **LWW by timestamp**: if `effectiveLocal >= effectiveRemote` → keep local & push; else apply remote & **move local version to history** (see below) then set clean |
| clocks skew badly | Prefer remote when `|skew|` suspicious AND local not edited in session; log warning |

### 7.2 History safety net

Before overwriting dirty local with remote:

1. Write snapshot row to `memo_history` (localId, content, timestamps, reason=`lww_lost`)
2. Apply remote
3. User can recover from history in later milestone (M7 minimum: store history even if UI minimal)

### 7.3 Delete conflicts

| Local | Remote | Result |
| ----- | ------ | ------ |
| dirty delete | exists | push delete |
| clean | deleted | delete local |
| dirty edit | deleted | V1: re-create on server (new serverName) **or** drop local with history — **choose re-create** to avoid data loss |

---

## 8. AuthGate

```
on 401:
  workspace.authState = needsReauth
  pause worker for workspace
  UI shows re-login

on successful login:
  authState = ok
  resume worker
```

Do not burn retries on permanent 401.

---

## 9. Attachment sync (M4+)

1. Local file path + hash stored first.
2. Queue `attachment.create` after parent memo has `serverName` (dependency ordering).
3. Upload binary → bind remote URL / name.
4. Download on pull if missing locally.

V1 limits: single-file sequential upload; size warning threshold.

---

## 10. Worker scheduling

| Trigger | Action |
| ------- | ------ |
| App start | start worker |
| Connectivity regained | kick cycle |
| Enqueue | kick cycle |
| Timer | every 5s light poll (configurable) |
| Manual “Sync now” | force push drain + pull |
| App background | platform-dependent; best-effort |

---

## 11. Observability

Expose streams:

```text
SyncStatusSnapshot
  state: idle | syncing | offline | authRequired | error
  pendingCount
  deadCount
  lastPullAt
  lastPushAt
  lastError?
```

Logging: task id, action, entityLocalId, duration, error code — **never** token.

---

## 12. Testing requirements

Minimum automated tests for Sync Engine:

1. Create offline → online push binds serverName
2. Update coalesce
3. Delete before push cancels create
4. LWW remote wins writes history
5. LWW local wins keeps dirty and pushes
6. 401 pauses queue
7. Backoff increases nextAttemptAt

---

## 13. Configuration knobs

| Key | Default |
| --- | ------- |
| pollInterval | 5s |
| pageSize | 50–100 |
| maxRetries before dead | 12 |
| fullReconcileInterval | 24h |
| pushConcurrency | 1 |
