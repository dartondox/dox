# dox_validation

Typed input for Dart: DTO classes with generated checks, and fluent schemas like Zod.

[![pub package](https://img.shields.io/pub/v/dox_validation.svg)](https://pub.dev/packages/dox_validation)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/dartondox/dox/blob/develop/LICENSE)

Part of [Dox](https://dartondox.dev), a web backend framework for Dart, like Laravel.
Source code: [github.com/dartondox/dox](https://github.com/dartondox/dox).

## Install

In a Dox app you do not add it. `dox_core` exports it. Outside Dox:

```bash
dart pub add dox_validation
dart pub add dev:dox_builder dev:build_runner
```

Dox 3.x is in alpha (`3.0.0-alpha.x`). The API can still change before the stable release.

## Use it

A DTO: a class with `@Dto()` and rule annotations. `dox_builder` writes the checks.

```dart
import 'package:dox_validation/dox_validation.dart';

part 'create_user.dto.g.dart';

@Dto()
class CreateUser {
  @Length(min: 3, max: 50)
  @Trim()
  final String name;

  @Email()
  final String email;

  const CreateUser({required this.name, required this.email});

  static const DtoSchema<CreateUser> schema = $CreateUserDto;
}
```

Run `dart run build_runner build`. Then:

```dart
ParseResult<CreateUser> result = await CreateUser.schema.safeValidateMap(input);
if (!result.success) {
  print(result.errors); // {'email': 'The email is not a valid email'}
}
```

A fluent schema, for input you only know at runtime:

```dart
final ObjectSchema createUser = v.object(<String, Schema<Object?>>{
  'name': v.string().trim().min(3).max(50),
  'email': v.string().email(),
  'age': v.coerce.int().min(18).optional(),
});

Map<String, dynamic> data = createUser.parse(input); // throws ValidationException
```

## Features

- All problems come back at once, each with a path, a code and a message.
- Messages can change per rule, per call or for the whole app (for other languages).
- `v.coerce` turns query and form text into numbers, booleans and dates.
- Async checks with `refineAsync` and `parseAsync`.
- JSON Schema (draft 2020-12) with `toJsonSchema()`. OpenAPI uses it.
- Every schema implements the [Standard Schema](https://standardschema.dev) interface.
- No dependencies.

## Documentation

- [Validation package](https://dartondox.dev/latest/packages/validation/)
- [Validation guide](https://dartondox.dev/latest/the-basic/validation/) and [rules reference](https://dartondox.dev/latest/the-basic/validation-rules/)
- [API reference](https://pub.dev/documentation/dox_validation/latest/)

## License

MIT. See [LICENSE](https://github.com/dartondox/dox/blob/develop/LICENSE).
