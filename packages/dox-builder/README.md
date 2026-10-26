# dox_builder

Code generator for Dox apps. It runs with `build_runner`.

[![pub package](https://img.shields.io/pub/v/dox_builder.svg)](https://pub.dev/packages/dox_builder)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/dartondox/dox/blob/main/LICENSE)

Part of [Dox](https://dartondox.dev), a web backend framework for Dart, like Laravel.
Source code: [github.com/dartondox/dox](https://github.com/dartondox/dox).

## Install

Add it as a dev dependency. A new app made with `dox create` already has it.

```bash
dart pub add dev:dox_builder dev:build_runner
```

To see what is ready and what may still change, read [Status and roadmap](https://dartondox.dev/latest/concepts/status-and-roadmap/).

## How it is used

You do not call this package from your code. Run the generator:

```bash
dart run build_runner build      # or: dox build_runner:build
dart run build_runner watch      # or: dox build_runner:watch
```

It writes:

- The `.g.dart` part of each `@DoxModel` model (the `<Name>Generator` class).
- The `.g.dart` part of each `@Dto` class (`$<Name>Dto`, the checks and the JSON Schema).
- The `.g.dart` part of the `@DoxEnv` env class.
- `lib/generated/container.g.dart`: every `@Inject()` class, router, provider and model binder, for `AppConfig(container: registerContainer)`.
- `lib/generated/dtos.g.dart`: every DTO of the app, for `AppConfig(dtos: dtos)`. An app with no DTO gets an empty list.
- `lib/generated/openapi.g.dart`: the OpenAPI docs, read from the routes, controllers, DTOs and models.

A bad DTO (a field that is not final, a type that is not supported, a bad regex) stops the build with a clear error.

## Documentation

- [Validation](https://dartondox.dev/latest/the-basic/validation/)
- [Models](https://dartondox.dev/latest/database/model/)
- [OpenAPI](https://dartondox.dev/latest/packages/openapi/)
- [API reference](https://pub.dev/documentation/dox_builder/latest/)

## License

MIT. See [LICENSE](https://github.com/dartondox/dox/blob/main/LICENSE).
