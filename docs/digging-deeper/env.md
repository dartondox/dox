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

- **Key**: the getter name in UPPER_SNAKE case. `appName` reads `APP_NAME`, `s3Bucket` reads `S3_BUCKET`. A run of capitals is one word: `dbURL` reads `DB_URL`. Use `@EnvKey('X')` for another name.
- **Default**: the getter body. It can be any expression, like `Platform.numberOfProcessors`. It runs only when the key is missing. A default can read another env getter and sees its loaded value, so `appEnv == 'development'` uses the real `APP_ENV`.
- **Every getter is a key**: also a getter whose body uses other getters. `bool get isDevelopment => appEnv == 'development';` reads `IS_DEVELOPMENT`. When `IS_DEVELOPMENT` is set, it wins over the body.
- **Use the getter, not `env`**: in a default, write `appEnv`, never `env.appEnv`. The global `env` is not ready while it loads. The app stops at startup with a `StateError`: "A default of AppEnv reads the global `env`. Use the getter directly".
- **Only this class**: the builder reads the getters of the `@DoxEnv()` class itself. Getters from a superclass or a mixin are not read from the env. A field (`final String x = ...;`) is a build error: use a getter.
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
  - DB_PORT must be an int
```

The error names the key, never the value. A value may be a secret, and this text goes to the log and to CI output.

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
APP_KEY=<output of dox key:generate>
DB_PORT=5432
```

- One `KEY=value` per line.
- Quotes around a value are removed. So `APP_NAME="My app"` gives `My app`. Use `"`, `'` or `` ` ``.
- A `=` inside the value is kept: `TOKEN=a=b` gives `a=b`.
- A line that starts with `#` is a comment.
- A `#` after a space starts a comment: `APP_PORT=3000 # dev` gives `3000`.
- A `#` with no space before it is kept: `DB_PASSWORD=abc#123` gives `abc#123`, and `COLOR=#fff` gives `#fff`.
- A `#` inside quotes is kept: `DB_PASSWORD="abc # 123"` gives `abc # 123`.
- `export KEY=value` is read like `KEY=value`.
- `KEY=` (empty, or only spaces) gives the default value, like a key that is not there.
- One line is one value. A quoted value can not go over more lines, so a multi-line PEM key does not work. Turn on `envExpand` (below) and write it on one line with `\n`: `JWT_KEY="-----BEGIN KEY-----\nabc\n-----END KEY-----"`. Or keep the key in a file and put the file path in the env.

### Use one value in another

`CoreFlags.envExpand` is off by default. Turn it on to use `${OTHER}` in a value:

```ini title=".env"
HOST=localhost
PORT=3000
APP_URL=http://${HOST}:${PORT}
GREETING="Hello\nWorld"
```

- `${OTHER}` works in an unquoted value and in a `"..."` value. It does not work in `'...'`.
- Dox looks for a real environment variable first, then for a key above this line. In tests, `.env.testing` also sees the keys of `.env`.
- A name that Dox does not find stays as it is: `${OTHER}`.
- In a `"..."` value, `\n`, `\t`, `\"`, `\\` and `\$` become a new line, a tab, `"`, `\` and `$`. Use `\$` to write a `$` that is not a variable.

The `.env` file is read before `AppConfig` exists. So you must set the flag in two places:

1. `Env.flags = flags;` at the top of `main()`, before any env value is read.
2. The same flags in `AppConfig(flags: flags)`.

```dart title="lib/config/app.dart"
import 'package:dox_core/dox_core.dart';

const CoreFlags flags = CoreFlags(envExpand: true);

AppConfig appConfig = AppConfig(
  appKey: Env.get('APP_KEY', ''),
  flags: flags,
  // ...
);
```

```dart title="bin/server.dart"
import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/app.dart';

void main() async {
  Env.flags = flags;
  Dox().initialize(appConfig);
  await Dox().startServer();
}
```

`my_app` is the `name` in your `pubspec.yaml`.

A test does not run `bin/server.dart`. So set `Env.flags = flags;` at the top of the `main()` of each test file too, before the app or the client starts:

```dart title="test/http_test.dart"
import 'package:dox_core/dox_core.dart';
import 'package:dox_core/testing.dart';
import 'package:my_app/config/app.dart';
import 'package:test/test.dart';

void main() {
  Env.flags = flags;
  late DoxTestClient client;

  setUpAll(() async {
    client = await DoxTestClient.start(appConfig);
  });
  // ...
}
```

Without it, `${OTHER}` stays as written in the test, and Dox prints the warning.

The server isolates follow the main isolate. You set nothing for them.
When the flag is on in `AppConfig` but `.env` was read without it, Dox prints a warning at start, once in each isolate.

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
    When `APP_ENV` is `development`, `local`, `test` or `testing`, it only logs a warning. Make a key with `dox key:generate`.
