# dox_annotation

Annotations and interfaces that the Dox packages share.

[![pub package](https://img.shields.io/pub/v/dox_annotation.svg)](https://pub.dev/packages/dox_annotation)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/dartondox/dox/blob/main/LICENSE)

Part of [Dox](https://dartondox.dev), a web backend framework for Dart, like Laravel.
Source code: [github.com/dartondox/dox](https://github.com/dartondox/dox).

## How it is used

You do not add this package yourself.
`dox_core` and `dox_orm` export it, so the names are already there when you import them.

It holds:

- `@DoxModel()` for models.
- `@DoxEnv()` and `@EnvKey('X')` for the typed env class.
- OpenAPI annotations: `@Summary`, `@Description`, `@Tags`, `@Request`, `@Body`, `@Query`, `@Response`, `@ApiDeprecated`, `@ApiIgnore`, `@DoxController`.
- Small interfaces that let the packages work together, like `IDoxRequest`, `IDoxMiddleware` and `IAuth`.

The DTO annotations (`@Dto`, `@Length`, `@Email`, ...) are in `dox_validation`.

To see what is ready and what may still change, read [Status and roadmap](https://dartondox.dev/latest/concepts/status-and-roadmap/).

## Documentation

- [OpenAPI annotations](https://dartondox.dev/latest/packages/openapi/)
- [Models](https://dartondox.dev/latest/database/model/)
- [API reference](https://pub.dev/documentation/dox_annotation/latest/)

## License

MIT. See [LICENSE](https://github.com/dartondox/dox/blob/main/LICENSE).
