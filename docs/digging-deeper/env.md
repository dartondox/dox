---
icon: lucide/file-cog
---

# Environment Variables

Declare your env keys one time, in a typed class, and read them as normal Dart values.

Each machine needs different settings, like the database password. Keep these values in environment variables or in a `.env` file, not in your code. Dox reads them through a typed class, so a missing key stops the app at startup.

## Defining env keys

A new project already has `lib/config/env.dart`. Its keys are in the [Env reference](../reference/env.md#read-by-a-new-project). Each getter is one env key:

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
  Duration get cacheTtl =>
      const Duration(minutes: 5);           // CACHE_TTL=5m
  List<String> get corsOrigins =>
      <String>[];                           // CORS_ORIGINS=a.com,b.com

  @EnvKey('AWS_BUCKET')
  String? get s3Bucket;                     // optional, null when not set
}

/// The env of the app. Read and checked one time, on first use.
final AppEnv env = AppEnv.load();
```

Run `dart run build_runner build` after each change to the class. It writes `env.g.dart`. The builder reads only the getters of the class itself, not getters of a superclass or a mixin.

### Key names

The key is the getter name in UPPER_SNAKE case. So `appName` reads `APP_NAME`, and `dbURL` reads `DB_URL`. To use another name, add `@EnvKey('X')`.

### Default values

The getter body is the default. It runs only when the key is missing. A default can use another getter. Write the getter directly, not `env.appPort`, or the app stops with a StateError:

```dart
String get appUrl => 'http://localhost:$appPort';
```

### Required and optional keys

- A getter with no body is required. A missing key stops the app.
- A nullable getter with no body, like `String? get s3Bucket;`, is optional. It is null when the key is missing.
- An empty value, or the text null, counts as missing.

### Types

| Type | Value in `.env` |
|------|-----------------|
| `String` | any text |
| `int`, `double`, `num` | `3000`, `0.5` |
| `bool` | `true`/`false`, `1`/`0`, `yes`/`no`, `on`/`off` (any case) |
| `Uri` | `https://dox.dev` |
| `Duration` | a number and a unit: `500ms`, `30s`, `5m`, `2h`, `1d`. A plain number is seconds. |
| an enum | the name of a value, any case: `debug` |
| `List<String>` | comma separated: `a, b, c`. Empty items are removed. |

Any other type is a build error.

### Missing or bad keys

At startup, `AppEnv.load()` checks every key. It throws one `EnvException` with all missing or bad keys:

```
EnvException: the env is not valid
  - APP_KEY is missing
  - DB_PORT must be an int
```

The error shows the key name, never the value.

## Reading env values

Import the config file and use `env`:

```dart
import 'package:my_app/config/env.dart';

DatabaseConfig databaseConfig = DatabaseConfig(
  connection: 'postgres',
  connections: <String, ConnectionConfig>{
    'postgres': ConnectionConfig(port: env.dbPort /* int */, ...),
  },
);
```

Keep only plain keys in the env class. For a computed value, use the app config, like `appConfig.isDevelopment`.

## Where values come from

Dox reads values from these places. The first one that has the key wins:

1. Real environment variables (from the shell, Docker or systemd).
2. In tests only: the `.env.testing` file. See [Testing: a test database](testing.md#use-a-test-database-with-envtesting).
3. The `.env` file in the folder where you start the app. It is optional.

### The `.env` file

The `.env` file has one `KEY=value` on each line:

```ini title=".env"
APP_NAME=dox
APP_KEY=<output of dox key:generate>
DB_PORT=5432
```

- Quotes around a value are removed: `APP_NAME="My app"` gives `My app`.
- A line that starts with `#` is a comment. A `#` after a space also starts a comment: `APP_PORT=3000 # dev` gives `3000`.
- `COLOR=#fff` gives `#fff`, because no space comes before the `#`.
- `KEY=` gives the default value.
- `export KEY=value` also works.
- A value is on one line only. For a PEM key, put the file path in the env, or use `\n` with `envExpand`.

## Use one value in another

Turn on `CoreFlags.envExpand` to build a value from other values:

```ini title=".env"
HOST=localhost
PORT=3000
APP_URL=http://${HOST}:${PORT}
GREETING="Hello\nWorld"
```

`${OTHER}` works in an unquoted value and in a `"..."` value. A name that Dox cannot find stays as `${OTHER}`. In a `"..."` value, `\n`, `\t`, `\"`, `\\` and `\$` are escapes.

### Turning on envExpand

The `.env` file is read before `AppConfig` exists. So set the flags in `AppConfig` and in `Env.flags`, at the top of `main()`:

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

A test does not run `bin/server.dart`. So also set `Env.flags = flags;` at the top of `main()` in each test file:

```dart title="test/http_test.dart"
void main() {
  Env.flags = flags;
  late DoxTestClient client;

  setUpAll(() async {
    client = await DoxTestClient.start(appConfig);
  });
  // ...
}
```

If you forget it, `${OTHER}` stays as it is, and Dox prints a warning.

## Generating the env class

Make `lib/config/env.dart` from your `.env.example`:

```bash
dox env:generate
```

Digits become an `int` default, and true or false become a `bool` default. An empty value becomes an optional `String?`. Any other value becomes a required `String`, so a secret in the example never goes into the code. The command does not overwrite an existing file.

## Checking the env

Print every missing or bad key. The command exits with code 1 when a key is wrong, so you can use it in CI:

```bash
dox env:check
```

## The app key

Dox uses `APP_KEY` to encrypt and sign data. Make one with `dox key:generate`. A missing, short or sample key stops `Dox().startServer()`. In development and test environments, it only logs a warning.

## Reading a key by name

Use `Env.get()` when you know the key name only at run time:

```dart
Env.get<String>('APP_KEY');               // '' when missing
Env.get('APP_KEY', 'default_value');
Env.get<int>('APP_PORT', 3000);
Env.get<bool>('SOCKETIO_ENABLED', false); // true, 1, yes, on
Env.get<String?>('AWS_BUCKET');           // null when not set
```

A missing or empty key gives the default. With no default, `int`, `num`, `double` and `bool` throw an ArgumentError. `Env.get()` reads the value again on each call, so do not use it on a hot path.

### The environment name

`Env.appEnv` gives `APP_ENV` in lower case. `Env.isTesting` is true under `dart test`, or when `APP_ENV=testing` is a real environment variable:

```dart
if (Env.appEnv == 'staging') {
  // ...
}
```

An empty `Env.appEnv` means production.

## Testing

To give your own values in a test, see [Testing](testing.md#test-the-env).

## Next steps

- [Environment variables](../reference/env.md): every env var that Dox reads.
- [Environments](../guides/environments.md): dev, staging and production config.
