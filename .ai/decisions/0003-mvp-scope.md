# ADR 0003: V1 MVP Scope Boundaries

- Status: Accepted
- Date: 2026-07-31

## Context

The V1.0 draft included Local, Memos, Cloud (Git/WebDAV/S3), full AI, and many social memo features. That scope risks failing to ship a reliable Memos client.

## Decision

**V1 ships:**

- Local workspace
- Memos server workspace with bidirectional sync (LWW)
- Search (FTS) + basic attachments
- Desktop (Win/macOS) + Android

**V1 explicitly defers:**

- Cloud storage workspaces
- Productized multi-provider AI
- Comments, reactions, shares as product features
- iOS / Linux packaging

## Consequences

- Storage Adapter and AIService may exist as stubs only.
- Success measured against vision MVP checklist, not feature count.
- Post-V1 milestones (M8+) own deferred work.
