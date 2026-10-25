---
icon: lucide/file-cog
---

# Environment Variables

Declare your env keys once, in a typed class.

Then `env.appPort` is an `int`, your IDE suggests every key, and a missing key stops the app at startup.

## The typed env class

A new project already has `lib/config/env.dart`. Its keys are listed in the [Env reference](../reference/env.md#read-by-a-new-project). This example shows the kinds of getters you can write:

```dart
import 'package:dox_core/dox_core.dart';

part 'env.g.dart';

enum LogLevel { debug, info, error }

@DoxEnv()
abstract class AppEnv {
  static AppEnv load([EnvReader? reader]) {
    return _$AppEnv.load(reader);
  }

  String get appName;                       // APP_NAME, required
  String get appKey;                        // APP_KEY, required
  int get dbPort => 5432;                   // DB_PORT, default 5432
  bool get appDebug => false;               // APP_DEBUG, default false
  LogLevel get logLevel => LogLevel.info;   // LOG_LEVEL=debug
  Duration get cacheTtl => const Duration(minutes: 5); // CACHE_TTL=5m
  List<String> get corsOrigins => <String>[];          // CORS_ORIGINS=a.com,b.com

  @EnvKey('AWS_BUCKET')
  String? get s3Bucket;                     // optional, null when not set
}

/// The env of the app. Read and checked once, on first use.
final AppEnv env = AppEnv.load();
```

Run `dart run build_runner build` after each change to the class. It writes `env.g.dart`. Then use `env` anywhere:

```dart
import 'package:my_app/config/env.dart';

DatabaseConfig databaseConfig = DatabaseConfig(
  connection: 'postgres',
  connections: <String, ConnectionConfig>{
    'postgres': ConnectionConfig(port: env.dbPort /* int */, ...),
  },
);
```

### The rules

- **Key**: the getter name in UPPER_SNAKE case. `appName` reads `APP_NAME`, `s3Bucket` reads `S3_BUCKET`. Use `@EnvKey('X')` for another name.
- **Default**: the getter body. It can be any expression, like `Platform.numberOfProcessors`. It runs only when the key is missing. A default can not read another env getter.
- **Optional**: a nullable getter with no body (`String? get s3Bucket;`). It is `null` when the key is missing.
- **Required**: any other getter with no body. A missing key stops the app.
- **Empty**: an empty value (or the text `null`) counts as missing.

### Types

| Type | Value in `.env` |
|------|-----------------|
| `String` | any text |
| `int`, `double`, `num` | `3000`, `0.5` |
| `bool` | `true`/`false`, `1`/`0`, `yes`/`no`, `on`/`off` (any case) |
| `Uri` | `https://dox.dev` |
| `Duration` | a number and a unit: `500ms`, `30s`, `5m`, `2h`, `1d`. A plain number is seconds: `300` is 5 minutes. |
| an enum | the name of a value, any case: `debug` |
| `List<String>` | comma separated: `a, b, c`. Empty items are dropped. |

Any other type is a build error.

### Fail fast

`AppEnv.load()` reads every key one time. Then it checks them all, and throws one `EnvException` that lists every missing or bad key:

```
EnvException: the env is not valid
  - APP_KEY is missing
  - DB_PORT must be an int, not "abc"
```

This happens once, when the app starts. After that, `env.dbPort` is a plain field read.

## Where values come from

Dox reads values from these places:

1. Real environment variables (set in the shell, Docker or systemd).
2. In tests only: the `.env.testing` file. See [Testing: a test database](testing.md#use-a-test-database-with-envtesting).
3. The `.env` file in the folder where you start the app. It is optional.

!!! info "The environment wins"
    A real environment variable wins over the `.env` file.
    So you can keep `.env` for development and use real variables in production.

### The `.env` file

```ini title=".env"
APP_NAME=dox
APP_KEY=3f9a1c7e5b2d4f6a8c0e1b3d5f7a9c2e
DB_PORT=5432
```

- One `KEY=value` per line.
- Quotes around a value are removed. So `APP_NAME="My app"` gives `My app`. Use `"`, `'` or `` ` ``.
- A `=` inside the value is kept: `TOKEN=a=b` gives `a=b`.
- A line that starts with `#` is a comment.
- A `#` after a space starts a comment: `APP_PORT=3000 # dev` gives `3000`.
- A `#` with no space before it is kept: `DB_PASSWORD=abc#123` gives `abc#123`.
- A `#` inside quotes is kept: `DB_PASSWORD="abc # 123"` gives `abc # 123`.

## Commands

```bash
dox env:generate   # make lib/config/env.dart from .env.example
dox env:check      # load the env and print every missing or bad key
```

`dox env:generate` reads `.env.example`:

- digits become an `int` with that default: `APP_PORT=3000` gives `int get appPort => 3000;`
- `true`/`false` become a `bool` with that default
- an empty value becomes an optional `String?`
- any other value becomes a required `String`. The example value is never a default, so a secret in the example can not leak into the code.
- `#` comment lines above a key become its doc comment

It does not overwrite an existing `lib/config/env.dart`. Run `dox build_runner:build` after it.

`dox env:check` exits with code 1 when a key is missing or bad. Use it in CI or before a deploy.

## Tests

To pass your own values in a test, see [Testing](testing.md#test-the-env).

## Env.get: the low-level way

`Env.get()` reads one key by name. Use it for a key you only know at run time. For normal config, use the typed class.

```dart
Env.get<String>('APP_KEY');             // '' when missing
Env.get('APP_KEY', 'default_value');
Env.get<int>('APP_PORT', 3000);
Env.get<bool>('SOCKETIO_ENABLED', false); // true, 1, yes, on
Env.get<String?>('AWS_BUCKET');          // null when it is not set
```

A missing or empty key gives the default. With no default:

- `String` gives an empty string `''`. It is never the text `"null"`.
- `String?` and `dynamic` give `null`. With no type, like `Env.get('KEY')`, the type is `dynamic`, so you get `null`.
- `int`, `num`, `double` and `bool` throw an `ArgumentError` with the key name. A value that is not a number throws too.

`Env.get()` looks up and converts the value on every call. Do not call it on a hot path.

!!! warning "APP_KEY"
    When `APP_KEY` is missing, not 32 characters, or a public sample key, `Dox().startServer()` stops with an error.
    When `APP_ENV` is `development`, `local` or `test`, it only logs a warning. Make a key with `dox key:generate`.
