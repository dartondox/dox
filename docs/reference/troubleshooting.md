---
icon: lucide/bug
---

# Troubleshooting

This page lists known problems, with the text you see, the cause and the fix.

The texts come from the source code.

## The native HTTP library did not load

**Symptom.** The app stops at start with this error:

```
Unsupported operation: dox_http_native did not load: <reason>.
Fix: install Rust (cargo, see https://rustup.rs), then run the app again ...
```

At build time (`dart pub get`, `dox serve` or `dox build`) you may also see one of these:

```
dox_http_native: no native library for <os>-<arch>. Install Rust (cargo) to build it from source.
dox_http_native: download dox_http_native-<os>-<arch>.<ext>: 404
dox_http_native: download dox_http_native-<os>-<arch>.<ext> failed: <error>
dox_http_native: sha256 of dox_http_native-<os>-<arch>.<ext> does not match
dox_http_native: cargo build failed
```

**Cause.** The build hook of `dox_http_native` (`hook/build.dart` in [its repo](https://github.com/dartondox/dox-http-native)) tries, in this order: the `lib_path` user define, a local `native/target/release` build, the GitHub release download, and `cargo build`. None of them worked. Common reasons:

- No internet during `dart pub get`, or the release has no build for your OS and CPU (there are builds for macOS arm64 and x64, Linux x64 and arm64, Windows x64).
- Rust is not installed, so the fallback `cargo build` can not run.
- You compiled with `dart compile exe`. It does not run build hooks, so no native library is in the binary.
- The `<reason>` is `native library ABI <x>, expected <y>`: the library on disk is from another version of the package.

**Fix.** Pick one:

1. Install Rust with [rustup](https://rustup.rs) and run `dart pub get` again. The hook builds the library with `cargo`.
2. When the reason is an ABI mismatch and you set `lib_path`, rebuild that library: `cargo build --release` in the `native` folder of the `dox-http-native` repo.
3. Download the library from the GitHub release `v<version>` of [dartondox/dox-http-native](https://github.com/dartondox/dox-http-native/releases) yourself and point to it in the root `pubspec.yaml`:

    ```yaml
    hooks:
      user_defines:
        dox_http_native:
          lib_path: /path/to/libdox_http_native.so
    ```

4. Build with `dox build` (it runs `dart build cli`), not with `dart compile exe`.

The native database drivers find their library the same way. When it does not load, the app stops too, with:

```
dox_postgres_native did not load: <reason>.
dox_mysql_native did not load: <reason>.
```

The fix is the same as above, with the `dox-postgres-native` or `dox-mysql-native` repo.

See [Native server](../digging-deeper/native-server.md), [Postgres native](../database/postgres-native.md) and [MySQL native](../database/mysql-native.md).

## Port already in use

**Symptom.** At start:

```
SocketException: dox_http_native: bind failed (<code>) (OS Error: errno = <errno>), port = 3000
```

`<errno>` is the OS error: `48` on macOS, `98` on Linux. `<code>` is `-1000` minus it: `-1048` on macOS, `-1098` on Linux.

**Cause.** Another process listens on the port. Often it is an old `bin/server.dart` that `dox serve` did not stop, or a second copy of the app.

**Fix.** Find and stop the process, or use another port.

```bash
lsof -i :3000          # macOS and Linux: who has the port
kill <pid>
```

Or set `APP_PORT=3001` in `.env` (a new project reads it into `serverPort`).

## build_runner: conflicting outputs

**Symptom.** `dox build_runner:build`, `dox serve` or `dox build` stops with a build_runner message that starts with `Conflicting outputs were detected`, and names files like `lib/generated/dtos.g.dart` or `lib/app/models/user/user.model.g.dart`.

**Cause.** The generated `.g.dart` files are on disk, but `.dart_tool/build` does not know them. This happens after a `git clone` with committed `.g.dart` files, after deleting `.dart_tool`, or after a Dart SDK update.

**Fix.** Delete the build cache and build again:

```bash
rm -rf .dart_tool/build
dart run build_runner build
```

If that is not enough, delete the named `.g.dart` files and build again. New build_runner versions have no `--delete-conflicting-outputs` flag, so the Dox CLI does not pass it.

## Ambiguous import: `Uuid`, `Name` or `Schema`

**Symptom.** The analyzer or the build says a name like `Uuid`, `Name`, `Range`, `Image` or `Schema` is an "ambiguous import".

**Cause.** `dox_core` exports the validation names of `dox_validation`: the rule annotations (`Uuid`, `Name`, `Range`, `Image`, ...) and the `Schema` class. Another import has a class with the same name, like `package:uuid`. `dox_orm` also has a `Schema` class.

**Fix.** Hide the name you do not use in that file:

```dart
import 'package:dox_core/dox_core.dart' hide Uuid;
import 'package:dox_orm/dox_orm.dart' hide Schema;
```

## A `.env` value with `#`

A `#` after a space starts a comment. The comment is not part of the value.

```ini
APP_PORT=3000 # dev port   -> 3000
DB_PASSWORD=abc#123        -> abc#123 (no space before the #)
DB_PASSWORD="abc # 123"    -> abc # 123 (quotes keep the #)
```

When a value must have ` #` in it (a space, then `#`), put the value in quotes. The quotes are removed.

## `Hash.make` throws on a long password

**Symptom.** Saving a user, or registering, gives a `500`. The log shows:

```
Invalid argument(s) (password): Password is too long (The length should be less than or equal to 72): "..."
```

**Cause.** `Hash.make()` uses bcrypt from the `bcrypt` package. bcrypt throws an `ArgumentError` when the password is longer than 72 bytes.

**Fix.** Refuse long passwords in your DTO, before you hash them:

```dart
@MaxLength(72)
final String password;
```

`@MaxLength` counts characters, not bytes. A password with non-ASCII characters can still be over 72 bytes.

`Hash.verify(password, hash)` does not throw. It gives `false` when `hash` is not a valid bcrypt hash, for example a plain password or an empty string in the column. Make sure every stored password went through `Hash.make()`.

For normal login use `Auth().attempt()` from `dox_auth`. See [Hashing](../security/hashing.md).

## MySQL 8 login fails

**Symptom.** The connection to MySQL 8 is refused at login, while the same user works from the `mysql` client. Often the user was made with the default `caching_sha2_password` plugin.

**Cause.** `caching_sha2_password` needs either TLS or the server RSA public key to send the password. A client that has neither can not log in.

**Fix.** The Dox MySQL driver (`dox_mysql_native`) supports `caching_sha2_password` (MySQL 8.4) and MariaDB 11. Check these settings on the connection in `lib/config/database.dart`:

| Setting | What to do |
| --- | --- |
| Remote host without TLS | Turn on `useSSL: true`. |
| `useSSL: true` | The server must have TLS on. |
| `host`, `port`, `user`, `password` | A wrong value gives the same login error. `DB_PORT` is `3306` by default for MySQL. |

As a last resort, change the user on the server:

```sql
ALTER USER 'app'@'%' IDENTIFIED WITH mysql_native_password BY 'secret';
```

## SQLite: the database file

**Symptom.** An `SqliteException` with `unable to open database file`, or an empty database after `dox build`.

**Cause.** `database` is a file path. A relative path is relative to the folder you start the app from. `dox build` tells you to run `cd build/bundle && ./bin/server`. So the default `DB_NAME=db/dox.sqlite` is then `build/bundle/db/dox.sqlite`. `dox build` does not copy your SQLite files into the bundle, so that database starts empty. SQLite makes a missing file, but not a missing folder.

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

Short errors, like a bad route, a missing DTO or a bad env key, are in the [Error index](errors.md).
