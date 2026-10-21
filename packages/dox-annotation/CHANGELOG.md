## Unreleased

- Needs Dart 3.13 or newer.
- All dependencies updated to their latest versions.
- OpenAPI annotations, all optional: `@Summary`, `@Description`, `@Tags`, `@Request`, `@Body`, `@Query`, `@Response`, `@ApiDeprecated`, `@ApiIgnore`, `@DoxController`. Lower case names work too (`@summary(...)`), except `@Response`.
- DTO annotations: `@Dto`, `@Length`, `@Email`, `@Min`, `@Max`, `@Pattern`, `@MinItems`, `@MaxItems`, `@Trim`, `@Format`.
- Breaking (small): these names are exported by `dox_core` too. `Pattern` now means the annotation in files that import `dox_core` (add `hide Pattern` if you need the `dart:core` one). If a file also imports a package with a `Request` or `Response` class (like `package:http`) without a prefix, add a prefix to that import.

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
