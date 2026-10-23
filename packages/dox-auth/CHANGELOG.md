## 3.0.0-alpha.5

- Breaking: `JwtAuthDriver.expiresIn` is 1 hour by default. Before, it was `null`, and tokens never expired.
- New: named guards work. Use `Auth(guard: 'admin')` and `AuthMiddleware(guard: 'admin')`. Before, only `defaultGuard` was used.
- A token keeps its guard name in the `aud` claim. A token from one guard does not work on another guard.
- `verifyToken` checks the `iss` claim when `issuer` is set.
- Breaking: `AuthDriver` methods get the guard name as a new parameter. `AuthEngine().guard(name)` replaces `AuthEngine().driver` and `AuthEngine().provider`.

## 3.0.0-alpha.4

- Version bump only, to match the other packages.

## 3.0.0-alpha.3

- Version bump only, to match the other packages.

## 3.0.0-alpha.2

- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.
- `dart_jsonwebtoken` 3.4 (`pointycastle` 4).

## 3.0.0-alpha.1

- Version 3 of Dox. All Dox packages now share one version.
- Needs Dart 3.6 or newer.
- See the [release notes](https://github.com/dartondox/dox/pull/112) for all main changes.
- Uses `dox_orm` (was `dox_query_builder`).
- `dart_jsonwebtoken` 3.

## 2.0.0

- Compatible for core version 2.0.

## 1.0.1

- Initial version.
