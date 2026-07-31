# Coding Conventions — Memos One

> Companion to [development-standards.md](./development-standards.md)

---

## 1. Language & style

- Dart 3.5+, null-safety on
- `prefer_single_quotes`, trailing commas, `dart format`
- `strict-casts`, `strict-inference`, `strict-raw-types` in analyzer
- No `print` in library code — use `logger`
- Avoid `dynamic` unless FFI/JSON boundary requires it; cast at edge

---

## 2. Architecture enforcement

| Layer | Allowed |
| ----- | ------- |
| `presentation/` | Widgets, controllers via Riverpod, navigation |
| `application/` | Use cases, notifiers, orchestration |
| `domain/` | Entities, value objects, repository **interfaces**, pure policies |
| `infrastructure/` | Drift, Dio, secure storage, sync worker |
| `feature/*/data` | Thin adapters implementing ports |

**Banned:**

```dart
// inside Widget
await dio.post(...);
await database.into(memos).insert(...);
```

---

## 3. State management

- **Riverpod only** for app state
- Feature providers live next to feature application layer
- Expose immutable state; prefer `AsyncValue` for loadable remote-ish local queries
- Side effects in notifiers/use cases, not `build()`

---

## 4. Naming

| Kind | Style | Example |
| ---- | ----- | ------- |
| Files | snake_case | `memo_repository.dart` |
| Classes | PascalCase | `MemoRepository` |
| Members | camelCase | `localId` |
| Constants | camelCase or lowerCamel | `appName` |
| Providers | camelCase + Provider | `memoListProvider` |

IDs: always `localId` / `serverName` as in data-model — do not invent `uuid`/`serverId` aliases in new code.

---

## 5. Error handling

- Domain/application errors: typed (`AppFailure` sealed hierarchy recommended)
- Map Dio errors at infrastructure boundary
- Surface user-readable messages in presentation; log technical details

---

## 6. Async & disposal

- Cancel subscriptions / Dio cancel tokens when providers dispose
- `unawaited` only with intent; prefer await
- Sync worker must be resilient to re-entry (mutex per workspace)

---

## 7. Testing

| Type | Put in | Prefer |
| ---- | ------ | ------ |
| Pure domain / LWW / coalesce | `test/unit` | Fast, no Flutter binding if possible |
| Widget smoke | `test/widget` | Critical pages |
| Integration | later `integration_test/` | Sync against mock server |

Use `mocktail` for ports.

---

## 8. Code generation

- Drift, freezed, json_serializable, riverpod_generator as needed
- Run: `dart run build_runner build --delete-conflicting-outputs`
- Do not hand-edit `*.g.dart` / `*.freezed.dart`

---

## 9. Security

- Tokens → secure storage only
- No secrets in logs, tests fixtures committed carefully
- Server “allow insecure TLS” behind explicit setting default **off**

---

## 10. Comments & docs

- Prefer clear names over noise comments
- Comment **why** for non-obvious sync/conflict behavior
- Public ports deserve brief dartdoc

---

## 11. Feature flags / stubs

Post-MVP modules (`ai/`, cloud adapters) may exist as stubs:

- Compile
- No dead UI entry unless behind “Coming soon”
- Must not break offline paths
