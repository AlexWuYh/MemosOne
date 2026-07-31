# Memos Compatibility Matrix

> Version: 1.1  
> Target upstream: [usememos/memos](https://github.com/usememos/memos)  
> Target API surface: **HTTP JSON API v1** (`/api/v1/...`), generated from protobuf services

---

## 1. Compatibility goals

| Goal | V1 |
| ---- | -- |
| Act as personal client for **current authenticated user** memos | Yes |
| Bidirectional sync of memo content & core flags | Yes |
| Faithful round-trip of fields we support | Yes |
| Full clone of web UI social features | No |
| Support every historical Memos API (pre-v1) | No |

**Supported instance policy (initial):**

- Prefer recent Memos builds that expose **API v1**
- On connect: call instance/user endpoint; fail fast with clear error if incompatible
- Record `serverVersion` / build metadata when available for diagnostics

---

## 2. Identity mapping

| Local | Remote (API v1) | Notes |
| ----- | --------------- | ----- |
| `Memo.localId` (UUID) | — | Client-generated; never send as server id |
| `Memo.serverName` | `Memo.name` e.g. `memos/{id}` | Set after create/list |
| `Memo.content` | `Memo.content` | Markdown |
| `Memo.visibility` | `Visibility` enum | PRIVATE / PROTECTED / PUBLIC |
| `Memo.pinned` | pinned field on Memo (as exposed) | Map per proto |
| `Memo.archived` / row state | state / row_status equivalent | Map per proto |
| `Memo.createdAt` | `create_time` | Store both local & server |
| `Memo.updatedAtServer` | `update_time` | Conflict key |
| Tags | Parsed from content `#tag` + server tag fields if present | Local FTS + tag index table |
| Attachment | `attachment_service` resources | Binary via upload APIs |

Resource names are strings; **do not** invent alternate REST shapes.

---

## 3. Service coverage

Legend: **R** = required V1, **P** = partial, **D** = deferred, **I** = ignore

### 3.1 Auth / User / Instance

| Capability | API area | V1 | Notes |
| ---------- | -------- | -- | ----- |
| Sign in | `auth_service` | **R** | Store access token securely |
| Current user | `user_service` | **R** | Display name, username |
| Instance info | `instance_service` | **P** | Version / profile for compatibility |
| SSO / IdP | `idp_service` | **D** | Post-V1 |
| User management | admin APIs | **I** | Not a client goal |

### 3.2 MemoService

| RPC / HTTP | V1 | Client behavior |
| ---------- | -- | --------------- |
| `CreateMemo` `POST /api/v1/memos` | **R** | Push create from queue |
| `ListMemos` `GET /api/v1/memos` | **R** | Pull with pagination + filter (creator = me) |
| `GetMemo` | **P** | On demand / repair |
| `UpdateMemo` `PATCH` + field mask | **R** | Push updates; send mask |
| `DeleteMemo` | **R** | Push delete after local soft-delete |
| `SetMemoAttachments` / list | **P** | Basic attachment sync in M4 |
| `SetMemoRelations` / list | **D** | No V1 UI |
| Comments APIs | **D** | — |
| Reactions APIs | **D** | — |
| Shares APIs | **D** | — |
| Link metadata | **D** | Optional later for preview |

### 3.3 AttachmentService

| Capability | V1 | Notes |
| ---------- | -- | ----- |
| Create / upload attachment | **P** | M4 |
| Get / download | **P** | Cache to local path |
| Delete | **P** | With memo lifecycle |

### 3.4 Other

| Service | V1 |
| ------- | -- |
| ShortcutService | **D** |
| AIService (server) | **D** (client AI is separate reserved module) |

---

## 4. List / filter conventions

V1 pull filter intent:

- Scope to **authenticated user's own memos** (primary workspace content)
- Pagination: use server page tokens / page size until exhausted
- Prefer incremental pull via `update_time` lower bound when server filter allows; else periodic full reconcile (see sync-spec)

If filter language differs across versions, isolate in `MemosMemoRemoteDataSource` with version adapters.

---

## 5. Field mask (updates)

Update pushes must use **field masks** for changed fields only when API requires it.

Typical mask paths:

- `content`
- `visibility`
- `pinned` (if field name differs, map in DTO layer)
- state/archive field

Never send local-only fields (`localId`, `dirty`, `syncStatus`) to server.

---

## 6. Error mapping

| HTTP / gRPC-ish | Local handling |
| --------------- | -------------- |
| 401 / unauthenticated | AuthGate: pause queue, mark workspace needs re-login |
| 403 | Surface error on task; do not infinite retry without backoff cap |
| 404 on update/delete | Treat as remote already gone → complete local delete / clear mapping |
| 409 / conflict | Apply LWW rules; may pull then re-queue |
| 429 / 5xx | Retry with exponential backoff |
| Network offline | Pause worker; keep queue |

---

## 7. Version matrix (living)

| Memos release line | API v1 | Client support |
| ------------------ | ------ | -------------- |
| Recent main / current releases with `/api/v1` | Yes | **Target** |
| Legacy REST-only older major | No | Unsupported; show upgrade message |

Update this table when first real instance testing happens (M2 D2D).

---

## 8. Out-of-scope remote behaviors

- Acting as another user
- Instance administration
- Federated / public timeline browsing as core UX
- Real-time websocket collaboration (unless added later as optimization)

---

## 9. Implementation placement

```text
lib/infrastructure/network/
  memos/
    memos_api_client.dart      # Dio + base URL + auth interceptor
    memo_remote_datasource.dart
    auth_remote_datasource.dart
    attachment_remote_datasource.dart
    dto/                       # JSON DTOs ↔ domain mappers
```

Domain entities remain client-centric; DTOs absorb proto/JSON naming churn.
