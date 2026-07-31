# 《Memos One》架构设计文档（Architecture Design Specification）

> Version：V1.0
>
> Status：Draft
>
> Project：Memos One
>
> Target：Windows / macOS / Android（后续支持 iOS / Linux）
>
> Design Principle：Offline First + Native Experience + AI Ready

---

# 1. 项目目标

## 1.1 产品定位

> **Memos One 是一个 Offline First 的 Memos 原生跨平台客户端。**

**Slogan（英文）**

> **One Client. Every Device. Your Memos.**

**Slogan（中文）**

> 一个客户端，连接所有设备。
>
> ‍

支持：

- ✅ Windows
- ✅ macOS
- ✅ Android
- ⏳ iOS（规划中）
- ⏳ Linux（规划中）

同时支持三种 Workspace：

- **Local Workspace**（纯本地）
- **Memos Workspace**（连接私有部署的 Memos）
- **Cloud Workspace**（Git / WebDAV / S3，后续规划）

---

## 1.2 设计目标

### 第一原则

永远不要因为网络影响用户体验。

例如：

```
点击保存

↓

立即完成

↓

后台同步
```

而不是：

```
点击保存

↓

HTTP

↓

等待

↓

成功
```

---

### 第二原则

所有数据都必须存在本地。

包括：

```
Memo

Tag

Resource

Setting

Workspace

History
```

全部支持离线访问。

---

### 第三原则

所有网络访问必须可以重试。

网络失败不能影响业务。

---

### 第四原则

Server 永远只是同步端。

而不是数据唯一来源。

---

## 1.3 Logo 思路

建议保持 ​**Memos 官方风格**，而不是重新设计一套品牌。

例如：

```
Memos One
```

下面：

```
Offline First Native Client
```

整个 Logo 延续：

- 极简
- 圆角
- Material Design
- Apple Notes 风格

这样别人一眼就知道：

> 这是 Memos 的生态产品。

而不是：

> 一个新的笔记软件。

# 2. 产品模式（Workspace）

本项目不采用 Online / Offline 两种模式。

统一抽象为：

Workspace。

一个 Workspace 就是一套独立的数据源。

支持以下类型。

---

## Workspace Type

### Local

```
SQLite

↓

结束
```

没有服务器。

完全本地。

适合：

个人日记

工作记录

学习笔记

---

### Memos Server

```
SQLite

↓

Sync Engine

↓

HTTP API

↓

Memos Server
```

连接私有部署。

自动同步。

---

### Cloud Storage（预留）

例如：

```
SQLite

↓

Git
```

或者：

```
SQLite

↓

WebDAV
```

或者：

```
SQLite

↓

S3
```

统一采用：

Storage Adapter。

以后无需修改业务代码。

---

# 3. 总体架构

采用 Clean Architecture。

```
+------------------------------------------------+
|                Presentation                    |
|  Page / Widget / Dialog / Theme                |
+------------------------------------------------+
                     │
                     ▼
+------------------------------------------------+
|               Application                      |
| UseCase / Provider / Command                   |
+------------------------------------------------+
                     │
                     ▼
+------------------------------------------------+
|                  Domain                         |
| Entity / Repository Interface                  |
+------------------------------------------------+
             │                     │
             ▼                     ▼
+---------------------+   +-----------------------+
| Local Datasource    |   | Remote Datasource     |
| SQLite              |   | HTTP API             |
+---------------------+   +-----------------------+
             │                     │
             └──────────┬──────────┘
                        ▼
                  Sync Engine
```

原则：

UI 不允许直接访问数据库。

UI 不允许直接访问 HTTP。

Repository 是唯一入口。

---

# 4. 技术栈

## Framework

Flutter

原因：

- 一套代码支持 Windows / macOS / Android
- Material3 + Fluent 风格兼容
- 性能优于 Electron
- 原生能力丰富

---

## Database

SQLite

ORM：

Drift

原因：

- 类型安全
- Migration 完整
- 支持复杂查询
- 支持 FTS5

---

## Network

Dio

---

## State Management

Riverpod

禁止：

Provider

GetX

Bloc

整个项目统一采用 Riverpod。

---

## Markdown

flutter\_markdown

未来可替换：

super\_editor

---

## Local Storage

Hive

仅保存：

```
Theme

Token

Workspace Config

Window State
```

业务数据全部进入 SQLite。

---

# 5. Offline First 设计

整个系统只有一个原则：

Local is Source of Truth。

例如：

创建 Memo：

```
User

↓

Repository

↓

SQLite

↓

UI刷新

↓

加入 SyncQueue

↓

后台同步
```

删除：

```
User

↓

SQLite

↓

UI

↓

Queue

↓

HTTP DELETE
```

修改：

完全一致。

---

禁止：

```
UI

↓

HTTP

↓

SQLite
```

---

# 6. 数据模型

## Memo

```
id

workspaceId

serverId

uuid

content

visibility

createTime

updateTime

pin

state

deleted

version

syncStatus

dirty
```

说明：

serverId

服务器 ID。

uuid

本地唯一 ID。

dirty

是否等待同步。

deleted

逻辑删除。

version

同步版本。

---

## Workspace

```
id

name

type

server

token

databasePath

createdTime
```

---

## Tag

```
id

memoId

name
```

---

## Attachment

```
id

memoId

type

mime

size

hash

localPath

remoteUrl

syncStatus
```

---

## SyncTask

```
id

workspaceId

entityType

entityId

action

retryCount

status

lastError

createTime
```

---

# 7. Sync Engine

整个项目最核心模块。

由五部分组成。

```
Repository

↓

Sync Queue

↓

Sync Worker

↓

Conflict Resolver

↓

Remote API
```

---

## Queue

所有操作：

```
Create

Update

Delete
```

全部进入：

Queue。

例如：

```
Create Memo

↓

Pending
```

后台：

```
每5秒

↓

扫描

↓

上传

↓

成功

↓

删除任务
```

---

## Retry

失败：

```
retry++

等待：

2s

5s

15s

30s

60s

300s
```

指数退避。

---

## Conflict

V1：

采用：

Last Write Wins。

以后：

支持 Merge。

---

# 8. Repository 设计

Repository 是整个系统唯一数据入口。

例如：

```
MemoRepository

create()

update()

delete()

archive()

pin()

search()

sync()
```

内部：

自动决定：

```
SQLite

HTTP

Queue
```

UI 永远不知道。

---

# 9. 搜索

采用：

SQLite FTS5。

禁止：

```
LIKE '%abc%'
```

支持：

- 全文搜索
- Tag 搜索
- 日期搜索
- Workspace 搜索
- 组合条件

---

# 10. UI 设计

桌面端：

```
+----------------+----------------------+----------------------+
| Workspace      | Memo List            | Memo Detail          |
|                |                      |                      |
+----------------+----------------------+----------------------+
```

移动端：

```
Memo List

↓

Memo Detail
```

采用导航切换。

---

统一支持：

- Light
- Dark
- System

支持 Accent Color。

---

# 11. AI 能力（预留）

所有 AI 功能必须通过统一接口。

```
AIService

summarize()

rewrite()

translate()

generateTitle()

extractTags()
```

Provider：

```
OpenAI

Claude

Gemini

Ollama
```

以后：

任何 Provider。

不用修改 UI。

---

# 12. 目录结构

```
lib/
 ├── app/
 ├── core/
 ├── feature/
 │    ├── memo/
 │    ├── workspace/
 │    ├── search/
 │    ├── sync/
 │    ├── setting/
 │    └── ai/
 ├── infrastructure/
 ├── domain/
 ├── application/
 └── shared/
```

每个 Feature：

```
memo/

data/

domain/

application/

presentation/
```

禁止跨 Feature 引用实现。

---

# 13. 开发阶段

|Sprint|目标|
| ----------| ------------------------------------------------|
|Sprint 1|Flutter 工程、主题、导航、SQLite、Riverpod|
|Sprint 2|Workspace、本地 Memo CRUD、Markdown|
|Sprint 3|Memos 登录、API 适配、Token 管理|
|Sprint 4|Sync Engine、冲突处理、后台同步|
|Sprint 5|搜索、附件、FTS5、图片缓存|
|Sprint 6|Windows/macOS 原生能力（托盘、快捷键、剪贴板）|
|Sprint 7|Android 优化、分享、通知、小组件|
|Sprint 8|AI 功能（总结、标签、改写、搜索增强）|

---

# 14. 非功能性要求（NFR）

|类别|要求|
| -----------| ------------------------------------|
|启动时间|≤ 2 秒（桌面）|
|新建 Memo|≤ 100ms（本地）|
|搜索响应|≤ 100ms（10 万条 Memo）|
|同步|后台异步，不阻塞 UI|
|离线可用|100%（除首次登录和首次同步外）|
|数据安全|本地数据库可加密（预留 SQLCipher）|
|扩展性|新增同步后端无需修改业务层|

---

# 15. AI Coding 约束（必须遵守）

为了保证项目可长期维护，并适合 AI 协同开发，所有代码必须遵守以下规则：

1. **UI 不直接访问数据库或网络**，所有数据经 Repository。
2. **业务逻辑不写在 Widget**，Widget 仅负责展示和事件转发。
3. **所有数据修改先写本地，再进入同步队列**，禁止同步成功后才写本地。
4. **Repository 只依赖抽象接口**，不依赖具体 HTTP 或 SQLite 实现。
5. **每个 Feature 独立分层**（Presentation、Application、Domain、Data），避免跨模块耦合。
6. **所有新增能力优先通过接口扩展**，避免修改已有核心逻辑，遵循 Open/Closed Principle。
7. **所有异步操作必须具备错误恢复能力**，包括自动重试、取消和状态反馈。
8. **任何新功能都不能破坏 Offline First 原则**，离线状态必须保持完整可用。
