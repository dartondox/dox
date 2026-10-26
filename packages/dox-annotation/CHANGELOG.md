## 3.0.0

- The first stable release.

## 3.0.0-rc.1

- `IDoxRequest.auth` is now a field (getter and setter), not only a getter. The auth is kept apart from the input.

## 3.0.0-alpha.17

- Version bump only, to match the other packages.

## 3.0.0-alpha.16

- Version bump only, to match the other packages.

## 3.0.0-alpha.15

- Version bump only, to match the other packages.

## 3.0.0-alpha.14

- New: `@Security.bearer(format: 'API key')` and `@Security.apiKey(header: 'X-API-Key')`. Put it above a middleware class to show its login scheme in the OpenAPI docs.

## 3.0.0-alpha.13

- Version bump only, to match the other packages.

## 3.0.0-alpha.12

- Version bump only, to match the other packages.

## 3.0.0-alpha.11

- Version bump only, to match the other packages.

## 3.0.0-alpha.10

- Version bump only, to match the other packages.

## 3.0.0-alpha.9

- New: `@Inject()`. Put it above a class and `dox_builder` adds the class to the Dox container. `@Inject(singleton: false)` makes a new instance each time.

## 3.0.0-alpha.8

- Version bump only, to match the other packages.

## 3.0.0-alpha.7

- Breaking: `IDox`, `IDoxWebsocket` and `WebsocketEvent` are removed. They were only used by `dox_websocket`.

## 3.0.0-alpha.6

- Version bump only, to match the other packages.

## 3.0.0-alpha.5

- New `timestamps` option on `@DoxModel`. `timestamps: false` turns off `created_at` and `updated_at`, like `$timestamps = false` in Laravel. `createdAt: null` or `updatedAt: null` turns off one of them.
- New `primaryKeyType` option on `@DoxModel`. Use `primaryKeyType: String` for a UUID key. The default is `int`.
- Fix: `IHttpException.toResponse()` now returns `{"code": errorCode, "message": message}` for a text message, so the client gets the `errorCode`. A `Map` message is returned as it is.

## 3.0.0-alpha.4

- Version bump only, to match the other packages.

## 3.0.0-alpha.3

- Version bump only, to match the other packages.

## 3.0.0-alpha.2

- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.
- OpenAPI annotations, all optional: `@Summary`, `@Description`, `@Tags`, `@Request`, `@Body`, `@Query`, `@Response`, `@ApiDeprecated`, `@ApiIgnore`, `@DoxController`. Lower case names work too (`@summary(...)`), except `@Response`.
- The DTO annotations (`@Dto`, `@Length`, `@Email`, ...) live in `dox_validation`. `dox_core` exports them.
- `IDoxRequest` has no `validate()` and no `processInputMapper()` any more. Use a DTO.
- Breaking (small): these names are exported by `dox_core` too. If a file also imports a package with a `Request` or `Response` class (like `package:http`) without a prefix, add a prefix to that import.
- New `@DoxEnv()` and `@EnvKey('X')` for the typed env class.

## 3.0.0-alpha.1

- Version 3 of Dox. All Dox packages now share one version.
- Needs Dart 3.6 or newer.
- See the [release notes](https://github.com/dartondox/dox/pull/112) for all main changes.

## 1.0.5

- Add IDoxMiddleware interface

## 1.0.5-alpha1.9

- Remove auth annotation

## 1.0.4

- Initial version.
