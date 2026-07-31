# ADR 0001: Offline First with Local Source of Truth

- Status: Accepted
- Date: 2026-07-31

## Context

Memos official experience is server-centric web. Mobile/desktop users need reliability under flaky networks. If the client treats the server as SoT, offline UX collapses and every keystroke risks latency.

## Decision

1. Local SQLite is the source of truth for user-visible data.
2. All mutations write local first, then enqueue sync.
3. Memos server is a sync peer, not the UX authority.

## Consequences

- Must build Sync Engine, conflict policy, and status UX.
- Possible divergence until sync completes (acceptable).
- Simpler mental model for offline; more engineering on merge/idempotency.
