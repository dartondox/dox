## Unreleased

- New: `SessionAuthDriver` keeps the login in the session, for web pages. Use `Auth().attemptSession(req, credentials)`, `Auth().loginSession(req, user)` and `Auth().logout(req)`. Login and logout give the session a new id. Needs `SessionMiddleware`.
- New: `AuthMiddleware(redirectTo: '/login')` sends a guest to that page instead of a 401.
- Change: the password check of `attempt` moved to `AuthDriver.checkCredentials`, so all drivers share it.

## 3.0.0-alpha.11

- Version bump only, to match the other packages.

## 3.0.0-alpha.10

- Version bump only, to match the other packages.

## 3.0.0-alpha.9

- Version bump only, to match the other packages.

## 3.0.0-alpha.8

- Security: a JWT secret (`SecretKey`) shorter than 32 bytes stops the app with an `ArgumentError` when `APP_ENV` is not `development`, `local` or `test`. In those envs it prints one warning line. Make a key with `dox key:generate` or `openssl rand -hex 32`.
- `Hash` now comes from `dox_core`. dox_auth had its own copy. `package:dox_auth/src/hash.dart` re-exports it. No change in behaviour. dox_auth now depends on dox_core.

## 3.0.0-alpha.7

- Perf: `attempt` runs bcrypt in another isolate (`Isolate.run`). Before, each login blocked the server isolate for the whole hash.
- Perf: the dummy hash for unknown users is made when the driver is created, in another isolate. Before, the first login paid for two hashes.
- New: `JwtAuthDriver(hashRounds: 10)`. Set it to the bcrypt cost of your stored hashes.
- New: `JwtAuthDriver(userCacheTtl: ...)`. Keeps the user of a token in memory for this time, so `verifyToken` does not run `find(id)` on every request. Off by default.
- Security: `JwtAuthDriver` throws `ArgumentError` when the `SecretKey` is empty. Before, an app with no `APP_KEY` signed tokens with an empty key, so anyone could make a token for any user.
- Security: `attempt` runs bcrypt also when no user is found, or when the user has no password. Before, an unknown email answered much faster than a wrong password, so the time told which emails have an account.

## 3.0.0-alpha.6

- Version bump only, to match the other packages.

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
