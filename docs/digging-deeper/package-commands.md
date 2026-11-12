---
icon: lucide/blocks
---

# Package commands

A package can add its own `dox` commands.

Your app can add its own commands too.
You do not write a `bin` file, and you do not register anything.
The `dox` CLI finds the commands by itself.

For example, `dox queue:table` comes from the `dox_queue` package, and `dox auth:tokens-table` comes from the `dox_auth` package.

## Use a package command

Add the package and run `dart pub get`. Then run the command:

```bash
dart pub add dox_queue
dox queue:table
```

`dox help` lists the commands of each package, under the package name.

## Add a command to your package

### 1. Write the command

A command extends `Command` from `package:dox_core/command.dart`.

```dart title="lib/src/commands/hello_command.dart"
import 'package:dox_core/command.dart';

class HelloCommand extends Command {
  @override
  String get name => 'hello:say';

  @override
  String get description => 'Say hello';

  /// optional, shown by `dox help`. The default is the name.
  @override
  String get usage => 'hello:say <name>';

  @override
  Future<void> run(List<String> args) async {
    print('Hello ${args.join(' ')}');
  }
}
```

`dox hello:say Ann` calls `run(['Ann'])`. The words after the name are the `args`.

### 2. List the commands

Make one library with a top-level `commands` list:

```dart title="lib/commands.dart"
import 'package:dox_core/command.dart';

import 'src/commands/hello_command.dart';

final List<Command> commands = <Command>[HelloCommand()];
```

### 3. Name the library in pubspec.yaml

```yaml title="pubspec.yaml"
dox:
  commands: package:my_package/commands.dart
```

The value must be a library of the package itself, like `package:my_package/commands.dart`. Use only letters, digits, `_`, `-`, `.` and `/` in the path, and no `..`. That is all. An app that depends on your package now has `dox hello:say`.

## Add a command to your app

It works the same way. Put the command in `lib/` of your app, and add the key to the app's own `pubspec.yaml`:

```yaml title="pubspec.yaml"
dox:
  commands: package:my_app/commands.dart
```

To make the command file, run `dox make:command send_report`. It writes `lib/app/commands/send_report_command.dart`, adds the command to `lib/app/commands/commands.dart`, and sets the `dox: commands:` key for you. The command name is `app:send-report`. See [`dox make:command`](../reference/cli.md#dox-makecommand).

## Exit codes and errors

- When `run` ends, `dox` exits with code 0.
- To fail, set `exitCode` from `dart:io` (like `exitCode = 1`), or throw. A thrown error is printed with its stack trace, and the exit code is 1.
- The exit code of the command is the exit code of `dox`, so scripts and CI see it.

## Write a migration

A command can add a migration file with `MigrationFile`. The file gets the same name as `dox make:migration` makes, like `2026_10_21_120000_create_queue_tables.dart`.

```dart
String? path = MigrationFile().create('create_queue_tables', source);
if (path == null) {
  print('A create_queue_tables migration is already in db/migration.');
  exitCode = 1;
}
```

`create` returns `null` and writes nothing when a migration with this name is already there, with any time in its name. `dox migrate` writes `db/migration/migrations.dart` again before it runs, and makes `bin/migrate.dart` when it is missing. So `dox migrate` runs the new file.

## Rules

- A built-in command always wins. When a package has a command with the same name as a built-in one, `dox` runs the built-in one. `dox help` marks the package command as not used.
- When two packages have a command with the same name, `dox <name>` prints an error with both package names, and exits with code 1.
- A bad `dox: commands:` key (not a library of the package, or a file that is not there) prints a warning with the package name. The commands of the other packages still work.
- An unknown command prints `Could not find a command named "<name>"`, with a hint about the `dox: commands:` key.

## How it works

1. `dox <name>` first looks for a built-in command.
2. Then it reads `.dart_tool/package_config.json`, and the `dox: commands:` key in the `pubspec.yaml` of each package and of the app.
3. It writes `.dart_tool/dox/commands.dart`. This file imports each commands library and runs the command with your args.
4. It runs that file with `dart run`.

`dox` writes the file again only when `.dart_tool/package_config.json`, your `pubspec.yaml`, or the `pubspec.yaml` of a package change. So after `dart pub get`, or after you change the key in a local package. When a package had a warning (like a commands library that is not there yet), `dox` looks again on the next run. The code of the commands is always the newest, because `dart run` compiles it each time.

`dox help` keeps the list of package commands in `.dart_tool/dox/commands.json`. It loads the list again when a package or a commands library (the file in the key) changes. When you change only a file that the commands library imports, `dox help` can show the old description until then. The command itself always runs the new code.

An app inside a pub workspace works too, also when the `workspace:` list uses a glob like `apps/*`. `dox` finds the workspace root from `.dart_tool/pub/workspace_ref.json`, which `dart pub get` writes in each member.
