---
icon: lucide/file-cog
---

# Environment Variables

Declare your env keys once, in a typed class, and read them as normal Dart values.

Your app needs different settings on each machine. For example, the database password on your laptop is not the one in production. You keep these values in environment variables or in a `.env` file, not in your code.

Dox reads them through a typed class. So `env.appPort` is an `int`, your IDE suggests every key, and a missing key stops the app at startup, not in the middle of a request.

## Defining env keys

A new project already has `lib/config/env.dart`. Its keys are listed in the [Env reference](../reference/env.md#read-by-a-new-project). Each getter in the class is one env key. This example shows the kinds of getters you can write:

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

Run `dart run build_runner build` after each change to the class. It writes `env.g.dart`.

### Key names

The key is the getter name in UPPER_SNAKE case. `appName` reads `APP_NAME`. A run of capitals is one word, so `dbURL` reads `DB_URL`. If you want another name, use `@EnvKey('X')`.

### Default values

The getter body is the default. It runs only when the key is missing. It can be any expression, like `Platform.numberOfProcessors`.

A default can use another env getter, and it gets the loaded value. Write the getter directly (`appPort`), not `env.appPort`, because the global `env` is not ready while it loads:

```dart
String get appUrl => 'http://localhost:$appPort';
```

This getter is still a key: it reads `APP_URL`, and when `APP_URL` is set, it wins over the body.

### Required and optional keys

- A getter with no body is required. A missing key stops the app.
- A nullable getter with no body, like `String? get s3Bucket;`, is optional. It is `null` when the key is missing.
- An empty value (or the text `null`) counts as missing.

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

### Missing or bad keys

When the app starts, `AppEnv.load()` reads and checks every key. If something is wrong, it throws one `EnvException` that lists every missing or bad key:

```
EnvException: the env is not valid
  - APP_KEY is missing
  - DB_PORT must be an int
```

The error names the key, never the value, because a value may be a secret and this text goes to logs and CI output.

## Reading env values

Import the config file and use `env` anywhere:

```dart
import 'package:my_app/config/env.dart';

DatabaseConfig databaseConfig = DatabaseConfig(
  connection: 'postgres',
  connections: <String, ConnectionConfig>{
    'postgres': ConnectionConfig(port: env.dbPort /* int */, ...),
  },
);
```

Keep only plain keys in the env class. A computed value, like "is this development", does not go there. Use `appConfig.isDevelopment` from the app config instead. It is `true` when `APP_ENV` is `development`.

## Where values come from

Dox reads values from these places. The first one that has the key wins:

1. Real environment variables (set in the shell, Docker or systemd).
2. In tests only: the `.env.testing` file. See [Testing: a test database](testing.md#use-a-test-database-with-envtesting).
3. The `.env` file in the folder where you start the app. It is optional.

So you can keep a `.env` file for development and use real environment variables in production.

### The `.env` file

The `.env` file has one `KEY=value` per line:

```ini title=".env"
APP_NAME=dox
APP_KEY=<output of dox key:generate>
DB_PORT=5432
```

- Quotes around a value are removed, so `APP_NAME="My app"` gives `My app`. Use `"`, `'` or `` ` ``.
- A line that starts with `#` is a comment. A `#` after a space also starts a comment: `APP_PORT=3000 # dev` gives `3000`.
- A `#` with no space before it, or inside quotes, is kept: `COLOR=#fff` gives `#fff`.
- `KEY=` (empty) gives the default value, the same as a missing key.
- `export KEY=value` works too.
- A value can not go over more lines. For a multi-line PEM key, keep the key in a file and put the file path in the env. Or turn on `envExpand` (below) and write it on one line with `\n`.

## Use one value in another

Sometimes you want to build a value from other values, like `APP_URL` from `HOST` and `PORT`. Turn on `CoreFlags.envExpand` for this. It is off by default.

```ini title=".env"
HOST=localhost
PORT=3000
APP_URL=http://${HOST}:${PORT}
GREETING="Hello\nWorld"
```

- `${OTHER}` works in an unquoted value and in a `"..."` value. It does not work in `'...'`.
- Dox looks for a real environment variable first, then for a key above this line. A name it does not find stays as `${OTHER}`.
- In a `"..."` value, `\n`, `\t`, `\"`, `\\` and `\$` become a new line, a tab, `"`, `\` and `$`.

### Turning on envExpand

The `.env` file is read before `AppConfig` exists. So you set the flags in two places: in `AppConfig`, and in `Env.flags` at the very top of `main()`, before any env value is read:

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

A test does not run `bin/server.dart`. So set `Env.flags = flags;` at the top of `main()` in each test file too:

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

If you forget it, `${OTHER}` stays as written, and Dox prints a warning.

## Generating the env class

If you have a `.env.example`, `dox env:generate` makes `lib/config/env.dart` from it:

```bash
dox env:generate   # make lib/config/env.dart from .env.example
```

- Digits become an `int` with that default: `APP_PORT=3000` gives `int get appPort => 3000;`.
- `true`/`false` become a `bool` with that default.
- An empty value becomes an optional `String?`.
- Any other value becomes a required `String`. The example value is never a default, so a secret in the example can not leak into the code.
- `#` comment lines above a key become its doc comment.

It does not overwrite an existing `lib/config/env.dart`. Run `dox build_runner:build` after it.

## Checking the env

`dox env:check` loads the env and prints every missing or bad key. It exits with code 1 when a key is wrong, so you can use it in CI or before a deploy:

```bash
dox env:check      # load the env and print every missing or bad key
```

## The app key

Dox needs `APP_KEY` to encrypt and sign data. Make one with `dox key:generate`.

When `APP_KEY` is missing, not 32 characters, or a public sample key, `Dox().startServer()` stops with an error. When `APP_ENV` is `development`, `local`, `test` or `testing`, it only logs a warning.

## Reading a key by name

Sometimes you only know the key name at run time. Use `Env.get()` for this. For normal config, use the typed class.

```dart
Env.get<String>('APP_KEY');             // '' when missing
Env.get('APP_KEY', 'default_value');
Env.get<int>('APP_PORT', 3000);
Env.get<bool>('SOCKETIO_ENABLED', false); // true, 1, yes, on
Env.get<String?>('AWS_BUCKET');          // null when it is not set
```

A missing or empty key gives the default. With no default:

- `String` gives `''`.
- `String?` and `dynamic` give `null`. `Env.get('KEY')` with no type is `dynamic`.
- `int`, `num`, `double` and `bool` throw an `ArgumentError` with the key name. A value that is not a number throws too.

`Env.get()` looks up and converts the value on every call, so do not call it on a hot path.

## Testing

To pass your own values in a test, see [Testing](testing.md#test-the-env).

## Details

- The builder only reads getters of the `@DoxEnv()` class itself. Getters from a superclass or a mixin are not read from the env. A field (`final String x = ...;`) is a build error.
- If a default reads the global `env`, the app stops at startup with a `StateError`: "A default of AppEnv reads the global `env`. Use the getter directly".
- After startup, `env.dbPort` is a plain field read.
- A `=` inside a value is kept: `TOKEN=a=b` gives `a=b`.
- With `envExpand`, `.env.testing` also sees the keys of `.env`.
- The first env read (like `Env.get()` or `env.appName`) loads `.env` with the flags of that moment. The file is not read again. If `Env.flags` was not set yet, `Dox().initialize` prints a warning.
- The server isolates follow the main isolate, so you set nothing for them. When the flag is on in `AppConfig` but `.env` was read without it, Dox prints a warning at start, once in each isolate.
