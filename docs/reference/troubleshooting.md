# Troubleshooting

Real problems, with the text you see, the cause and the fix. The texts come from the source code.

## The native HTTP library did not load

**Symptom.** One line at start, on stderr:

```
[dox] warning: dox_http_native did not load, using the dart:io server (<reason>)
```

and the start line says `(dart:io)` instead of `(native)`:

```
Server started at http://[::]:3000 with 8 isolate (dart:io)
```

At build time (`dart pub get`, `dox serve` or `dox build`) you may also see one of these:

```
dox_http_native: no native library for <os>-<arch>. Dox will use dart:io.
dox_http_native: download dox_http_native-<os>-<arch>.<ext>: 404
dox_http_native: download dox_http_native-<os>-<arch>.<ext> failed: <error>
dox_http_native: sha256 of dox_http_native-<os>-<arch>.<ext> does not match
dox_http_native: cargo build failed
```

**Cause.** The build hook of `dox_http_native` (`packages/dox-http-native/hook/build.dart`) tries, in this order: the `lib_path` user define, a local `native/target/release` build, the GitHub release download, and `cargo build`. None worked. Common reasons:

- No internet during `dart pub get`, or the release has no build for your OS and CPU (there are builds for macOS arm64 and x64, Linux x64 and arm64, Windows x64).
- Rust is not installed, so the fallback `cargo build` can not run.
- You compiled with `dart compile exe`. It does not run build hooks, so no native library is in the binary.
- The `<reason>` is `native library ABI <x>, expected <y>`: the library on disk is from another version of the package.

**Fix.** Pick one:

1. Accept `dart:io`. The app works, only slower. To hide the warning set `DOX_SERVER=dartio` or `server: ServerBackend.dartIo` in `AppConfig`.
2. Install Rust with [rustup](https://rustup.rs) and run `dart pub get` again. The hook builds the library with `cargo`.
3. Download the library from the GitHub release `dox_http_native-v<version>` yourself and point to it in the root `pubspec.yaml`:

    ```yaml
    hooks:
      user_defines:
        dox_http_native:
          lib_path: /path/to/libdox_http_native.so
    ```

4. Build with `dox build` (it runs `dart build cli`), not with `dart compile exe`.

The same applies to the native database drivers. The warning is then:

```
[dox] warning: dox_postgres_native did not load, using the Dart postgres driver (<reason>)
[dox] warning: dox_mysql_native did not load, using the Dart mysql driver (<reason>)
```

The Dart driver is used. To choose it on purpose set `DOX_DB_DRIVER=dart` or `extra: {'native': false}` on the connection.

See [Native server](../digging-deeper/native-server.md), [Postgres native](../database/postgres-native.md) and [MySQL native](../database/mysql-native.md).

## Port already in use

**Symptom.** With the `dart:io` server:

```
SocketException: Failed to create server socket (OS Error: Address already in use, errno = 48), address = ::, port = 3000
```

(`errno = 48` on macOS, `errno = 98` on Linux.) With the native server:

```
SocketException: dox_http_native: bind failed (<code>), port = 3000
```

**Cause.** Another process listens on the port. Often it is an old `bin/server.dart` that `dox serve` did not stop, or a second copy of the app.

**Fix.** Find and stop the process, or use another port.

```bash
lsof -i :3000          # macOS and Linux: who has the port
kill <pid>
```

Or set `APP_PORT=3001` in `.env` (a new project reads it into `serverPort`).

## build_runner: conflicting outputs

**Symptom.** `dox build_runner:build`, `dox serve` or `dox build` stops with a build_runner message that starts with `Conflicting outputs were detected`, and names files like `lib/dtos.g.dart` or `lib/app/models/user/user.model.g.dart`.

**Cause.** The generated `.g.dart` files are on disk, but `.dart_tool/build` does not know them. This happens after a `git clone` with committed `.g.dart` files, after deleting `.dart_tool`, or after a Dart SDK update.

**Fix.** Delete the build cache and build again:

```bash
rm -rf .dart_tool/build
dart run build_runner build
```

If that is not enough, delete the named `.g.dart` files and build again. Older build_runner versions accept `dart run build_runner build --delete-conflicting-outputs`. Newer versions removed that flag, so the Dox CLI does not pass it.

## `dox create` throws `RangeError`

**Symptom.**

```
dox create my_app
RangeError (index): Invalid value: Only valid value is 0: 1
```

**Cause.** A bug in the `dox` CLI up to `3.0.0-alpha.4`: the `create` command read the `--version` flag before it checked that one was given. The same versions also downloaded an old project template.

**Fix.** Update the CLI. The fix is in `3.0.0-alpha.5`:

```bash
dart pub global activate dox ^3.0.0-alpha
```

## A `.env` value with `#`

A `#` after a space starts a comment. The comment is not part of the value.

```ini
APP_PORT=3000 # dev port   -> 3000
DB_PASSWORD=abc#123        -> abc#123 (no space before the #)
DB_PASSWORD="abc # 123"    -> abc # 123 (quotes keep the #)
```

When a value must have ` #` in it (a space, then `#`), put the value in quotes. The quotes are removed.

## `Hash.verify` throws on a bad hash

**Symptom.**

```
Invalid argument(s) (salt): Invalid salt length (The length should be greater than or equal to 28): "..."
```

or

```
Invalid argument(s) (salt): Invalid salt version: "..."
```

or, when the password is long:

```
Invalid argument(s) (password): Password is too long (The length should be less than or equal to 72): "..."
```

**Cause.** `Hash.verify(password, hash)` calls `BCrypt.checkpw` from the `bcrypt` package. It throws an `ArgumentError` when `hash` is not a bcrypt hash (it must start with `$2` and be at least 28 characters), for example when the column holds a plain password, an empty string or a hash from another algorithm. It also throws when the password is longer than 72 bytes.

**Fix.**

- Make sure every stored password went through `Hash.make()`. A plain password in the column is a bug in the code that saved it.
- Check the hash before you compare it, and treat a bad one as a failed login:

    ```dart
    bool ok = hash.startsWith(r'$2') && Hash.verify(password, hash);
    ```

- Refuse passwords longer than 72 bytes in your DTO, for example `@Length(max: 72)`.

For normal login use `Auth().attempt()` from `dox_auth`. See [Hashing](../security/hashing.md).

## MySQL 8 login fails

**Symptom.** The connection to MySQL 8 is refused at login, while the same user works from the `mysql` client. Often the user was made with the default `caching_sha2_password` plugin.

**Cause.** `caching_sha2_password` needs either TLS or the server RSA public key to send the password. A client that has neither can not log in.

**Fix.** Both Dox drivers handle this by default:

- The native driver (`dox_mysql_native`) works with MySQL 8.4 `caching_sha2_password` and MariaDB 11.
- The Dart driver asks the server for its RSA key (`allowPublicKeyRetrieval` is `true` by default), so it works without TLS. Migrations do the same.

So check these settings on the connection in `lib/config/database.dart`:

| Setting | What to do |
| --- | --- |
| `extra: {'allowPublicKeyRetrieval': false}` | Remove it, or give the key in `extra: {'serverPublicKey': '...'}`. |
| `useSSL: true` | The server must have TLS on. |
| `host`, `port`, `user`, `password` | A wrong value gives the same login error. `DB_PORT` is `3306` by default for MySQL. |

As a last resort, change the user on the server:

```sql
ALTER USER 'app'@'%' IDENTIFIED WITH mysql_native_password BY 'secret';
```

## SQLite: the database file

**Symptom.** An `SqliteException` with `unable to open database file`, or an empty database after `dox build`.

**Cause.** `database` is a file path. A relative path is relative to the folder you start the app from. `dox build` tells you to run `cd build/bundle && ./bin/server`, so `dox.sqlite` is then `build/bundle/dox.sqlite`. SQLite makes a missing file, but not a missing folder.

**Fix.**

- Use an absolute path, or make the folder first.
- Set it with `DB_NAME` (a new project reads it): `DB_NAME=/var/lib/my_app/dox.sqlite`.
- Migrations use `DB_DATABASE` or `DB_NAME` as the path too. Use the same value for both.

!!! warning "`:memory:` and isolates"
    `:memory:` opens a new empty database in each isolate. With `totalIsolate` above 1, every isolate sees different data. Use a file, or `totalIsolate: 1`.

Dox opens a file database with `journal_mode = WAL`, `synchronous = NORMAL`, `foreign_keys = ON` and `busy_timeout = 5000` (change it with `extra: {'busyTimeout': ...}`).

## `dox: command not found` after `dart pub global activate`

**Symptom.**

```
zsh: command not found: dox
```

right after `dart pub global activate dox ^3.0.0-alpha`.

**Cause.** `dart pub global activate` puts the `dox` script in `$HOME/.pub-cache/bin`. That folder is not in your `PATH`.

**Fix.** Add it to your shell profile and open a new terminal:

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

On Windows the folder is `%LOCALAPPDATA%\Pub\Cache\bin`.

## Other startup errors

| Text | Cause | Fix |
| --- | --- | --- |
| `APP_KEY is not set. Run `dox key:generate` and put the key in .env` | `appKey` is empty. A warning in development, a `StateError` that stops the app when `APP_ENV=production`. | Run `dox key:generate`, or set `APP_KEY` in the environment. |
| `Env key "<KEY>" is not set and has no default` | `Env.get<int>()`, `<num>`, `<double>` or `<bool>` with no value and no default. | Set the key, or pass a default. |
| `<T> is not a known DTO. Add @Dto() to it, run `dart run build_runner build` and set `dtos: dtos` (lib/dtos.g.dart) in AppConfig.` | `req.validate<T>()` can not find the DTO. | Do what the text says. |
| `Route <METHOD> <path>: the controller parameter type <T> is not known. ...` | A controller parameter is not `DoxRequest`, a DTO, or `String`, `int`, `double`, `num`, `bool`. | Change the type, or add the DTO to `AppConfig.dtos`. |
| `Route <METHOD> <path>: a controller can have one @Dto only.` | Two DTO parameters on one controller. | Merge them into one DTO. |
| `Route <METHOD> <path>: only positional parameters are supported, not named or [optional] ones` | The controller has named or `[optional]` parameters. | Use positional parameters. |
| `db/migration has Dart migrations, but bin/migrate.dart is missing.` | `dox migration:*` found Dart migration files but no entry point. | Run `dox make:migration <name>` once. It writes `bin/migrate.dart`. |
| `<name> not found` (an `Exception` from `DatabaseConfig`) | `DatabaseConfig.connection` names a key that is not in `connections`. | Fix `DB_CONNECTION` or the map. |
| `Storage disk "<name>" has unknown driver "<type>"` | A disk in `StorageConfig` has a `driver` other than `local`, `s3` or `memory`. | Fix the driver name. |
| `Windows: the native server runs on one isolate` | Windows has no `SO_REUSEPORT`. | Not an error. Use `DOX_SERVER=dartio` to use every core on Windows. |
| `WebSocket or Socket.IO routes: using the dart:io server` | The native server can not upgrade to WebSocket yet. | Not an error. `DOX_SERVER=native` forces native, then WebSocket upgrades fail with `500`. |
