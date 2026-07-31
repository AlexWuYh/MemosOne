# Local Data Model

> Version: 1.1  
> Storage: SQLite via Drift  
> One database file per workspace (recommended)

---

## 1. Identity strategy

**Single primary key for all local entities: `localId` (UUID v4 string).**

| Concept | Field | Notes |
| ------- | ----- | ----- |
| Local PK | `localId` | Generated client-side; stable offline |
| Server resource | `serverName` | e.g. `memos/42`; null until known |
| Workspace scope | `workspaceId` | Every business row is scoped |

**Do not** use auto-increment ints as cross-device identity.  
**Do not** use `serverName` as local PK (null before first sync).

Deprecated from V1.0 draft: separate `id` + `uuid` + `serverId` triple → replaced by `localId` + `serverName`.

---

## 2. Workspace registry

Stored in a **app-level** DB or registry file (not necessarily per-workspace DB):

```text
Workspace
  localId           TEXT PK
  name              TEXT
  type              ENUM local | memos | cloud
  serverBaseUrl     TEXT?          # memos only
  databasePath      TEXT           # absolute/relative path to WS DB
  createdAt         DATETIME
  updatedAt         DATETIME
  lastOpenedAt      DATETIME?
  initialSyncCompleted BOOL
  authState         ENUM none | ok | needsReauth
  serverVersion     TEXT?
```

**Secrets:**

```text
SecureStorage keys:
  workspace.{localId}.accessToken
  # optional refresh tokens later
```

Never store access tokens in SQLite plaintext.

---

## 3. Per-workspace tables

### 3.1 memo

```text
Memo
  localId            TEXT PK
  serverName         TEXT? UNIQUE
  content            TEXT NOT NULL
  visibility         ENUM private | protected | public
  pinned             BOOL DEFAULT false
  archived           BOOL DEFAULT false
  deletedAt          DATETIME?          # soft delete
  createdAtLocal     DATETIME NOT NULL
  updatedAtLocal     DATETIME NOT NULL
  createdAtServer    DATETIME?
  updatedAtServer    DATETIME?
  syncStatus         ENUM clean | dirty | syncing | error
  dirty              BOOL NOT NULL DEFAULT false
  contentHash        TEXT?              # optional idempotency aid
  lastError          TEXT?
  version            INT NOT NULL DEFAULT 0  # local monotonic edit counter
```

Indexes:

- `(pinned, updatedAtLocal DESC)`
- `(archived, deletedAt)`
- `(serverName)`
- `(dirty)` where dirty = 1

### 3.2 memo_fts (FTS5)

Virtual table content = memo content (and optional denormalized tags string).  
Sync FTS on insert/update/delete via Drift triggers or explicit writes.

### 3.3 tag + memo_tag

Tags are primarily derived from Markdown `#tags`, but indexed for query:

```text
Tag
  localId     TEXT PK
  name        TEXT NOT NULL UNIQUE   # normalized lowercase

MemoTag
  memoLocalId TEXT
  tagLocalId  TEXT
  PRIMARY KEY (memoLocalId, tagLocalId)
```

Recompute `MemoTag` on content save.

### 3.4 attachment

```text
Attachment
  localId         TEXT PK
  memoLocalId     TEXT NOT NULL
  serverName      TEXT?
  mimeType        TEXT
  sizeBytes       INT
  hashSha256      TEXT?
  localPath       TEXT?
  remoteUrl       TEXT?
  syncStatus      ENUM ...
  dirty           BOOL
  createdAtLocal  DATETIME
  updatedAtLocal  DATETIME
```

### 3.5 sync_task

See [sync-spec.md](./sync-spec.md).

### 3.6 memo_history

```text
MemoHistory
  localId         TEXT PK
  memoLocalId     TEXT NOT NULL
  content         TEXT NOT NULL
  capturedAt      DATETIME NOT NULL
  reason          ENUM user_edit | lww_lost | pre_delete
  serverName      TEXT?
```

Retention: V1 keep last N=20 per memo or 30 days (configurable later).

### 3.7 sync_cursor

```text
SyncCursor
  key             TEXT PK    # e.g. memo_pull
  value           TEXT       # opaque cursor / ISO timestamp
  updatedAt       DATETIME
```

---

## 4. Soft delete lifecycle

1. User deletes → set `deletedAt`, `dirty=true`, enqueue delete (if `serverName` set).
2. If never synced (`serverName == null`) → remove row + cancel create task.
3. After remote delete ack → hard delete local row (or keep tombstone short period).

List queries default: `deletedAt IS NULL`.

---

## 5. Visibility enum mapping

| Local | Memos API |
| ----- | --------- |
| `private` | `PRIVATE` |
| `protected` | `PROTECTED` |
| `public` | `PUBLIC` |

Default for new local memos: `private`.

---

## 6. Migration policy

- Drift schema version starts at `1`
- Every schema change: numbered migration + note in this doc
- Never destructive migrate without export path once shipping

---

## 7. Multi-workspace isolation

| Resource | Isolation |
| -------- | --------- |
| SQLite file | Per workspace |
| Secure tokens | Keyed by workspace localId |
| Temp attachment files | Under workspace data dir |
| FTS | Inside workspace DB |

Switching workspace = switch DB connection + providers scope.

---

## 8. Mapping from V1.0 draft fields

| Draft | V1.1 |
| ----- | ---- |
| `id` | removed as PK concept |
| `uuid` | `localId` |
| `serverId` | `serverName` (resource name string) |
| `state` | `archived` (+ optional raw server state column if needed) |
| `deleted` bool | `deletedAt` timestamp |
| dual dirty/syncStatus unclear | defined state machine in sync-spec |
