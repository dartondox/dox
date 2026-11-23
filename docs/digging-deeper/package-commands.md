---
icon: lucide/blocks
---

# Package commands

A package can add its own `dox` commands.

Your app can add its own commands too. You do not write a `bin` file, and you do not register anything, because the `dox` CLI finds the commands by itself. For example, `dox queue:table` comes from the `dox_queue_database` package, and `dox auth:tokens-table` comes from the `dox_auth` package.

## Using a package command

Add the package and run `dart pub get`. Then run the command:

```bash
dart pub add dox_queue_database
dox queue:table
```

`dox help` lists the commands of each package, under the package name.

## Add a command to your package

A package command needs three things: the command class, a list of commands, and a key in `pubspec.yaml`.

### 1. Write the command

A command extends `Command` from `package:dox_core/command.dart`. The `run` method gets the words after the command name as `args`:

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

So `dox hello:say Ann` calls `run(['Ann'])`.

A package that does not use `dox_core` imports `package:dox_annotation/command.dart` instead.

### 2. List the commands

Make one library with a top-level `commands` list:

```dart title="lib/commands.dart"
import 'package:dox_core/command.dart';

import 'src/commands/hello_command.dart';

final List<Command> commands = <Command>[HelloCommand()];
```

### 3. Name the library in pubspec.yaml

Add the `dox: commands:` key. Its value must be a library of the package itself:

```yaml title="pubspec.yaml"
dox:
  commands: package:my_package/commands.dart
```

That is all. An app that depends on your package now has `dox hello:say`.

## Add a command to your app

It works the same way. The easy way is `dox make:command`:

```bash
dox make:command send_report
```

It writes `lib/app/commands/send_report_command.dart`, adds the command to `lib/app/commands/commands.dart`, and sets the `dox: commands:` key in your `pubspec.yaml`. The command name is `app:send-report`. See [`dox make:command`](../reference/cli.md#dox-makecommand).

If you write it by hand, put the command in `lib/` of your app and add the key to the app's own `pubspec.yaml`:

```yaml title="pubspec.yaml"
dox:
  commands: package:my_app/commands.dart
```

## Failing a command

When `run` ends, `dox` exits with code 0. If something went wrong, set `exitCode` from `dart:io`, or throw:

```dart
exitCode = 1;
```

A thrown error is printed with its stack trace, and the exit code is 1. The exit code of the command is the exit code of `dox`, so scripts and CI see it.

## Writing a migration

Some packages need a table, so their command adds a migration file. Use `MigrationFile` for this. The file gets the same name as `dox make:migration` makes, like `2026_10_21_120000_create_queue_tables.dart`:

```dart
String? path = MigrationFile().create('create_queue_tables', source);
if (path == null) {
  print('A create_queue_tables migration is already in db/migration.');
  exitCode = 1;
}
```

`create` returns `null` and writes nothing when a migration with this name is already there. The next `dox migrate` runs the new file.

## Ship an install command

`dox add <x>` adds the package `dox_x`, then runs its `<x>:install` command. So if your package needs setup (config files, `.env` keys, a provider), ship an `<x>:install` command.

Use `Installer` from `package:dox_annotation/install.dart`. Each step is safe to run twice, because it never overwrites a file and never adds a key twice:

```dart title="lib/src/commands/hello_install_command.dart"
import 'package:dox_annotation/command.dart';
import 'package:dox_annotation/install.dart';

class HelloInstallCommand extends Command {
  @override
  String get name => 'hello:install';

  @override
  String get description => 'Set up dox_hello in this app';

  @override
  Future<void> run(List<String> args) async {
    Installer installer = Installer();
    String app = installer.appName;
    installer.writeFile(
      'lib/config/hello.dart',
      "import 'package:$app/config/env.dart';\n",
    );
    installer.addEnvGetter("String get helloName => 'world';");
    installer.addEnv('HELLO_NAME', 'world');
    await installer.buildRunner();
    installer.printSummary(<String>['Restart the server.']);
  }
}
```

| Method | What it does |
| --- | --- |
| `writeFile(path, content)` | Writes the file only when it is not there. |
| `makeFolder(path)` | Makes the folder when it is not there. |
| `addEnv(key, value)` | Adds `KEY=value` to `.env.example` and `.env` when the key is missing. A key that is there is never changed. |
| `addEnvGetter(getter)` | Adds a getter to `AppEnv` in `lib/config/env.dart` when the class has no member with that name. When it can not find the class, it changes nothing and prints a hint. |
| `addDependency(package, dev: false)` | Runs `dart pub add` when the app does not have the package. |
| `buildRunner()` | Runs `dart run build_runner build`. |
| `note(line)` | Adds your own line to the summary, like `added    hooks to pubspec.yaml`. |
| `printSummary(nextSteps)` | Prints what was done and the next steps. Sets exit code 1 when a step failed. |

Some tips for a good install command:

- Read the options from `args`, like `--driver=postgres`. Give a good default, so `dox add <x>` with no options works.
- Test it on an app made without your package. Run it twice and check that nothing changes the second time.
- Add `dox add <x>` to the skill of your package (`skills/<name>/SKILL.md`), so AI agents set it up the same way.

`dox_orm` has an example: `orm:install`.

## Details

### Name clashes and errors

- A built-in command always wins. If a package has a command with the same name as a built-in one, `dox` runs the built-in one, and `dox help` marks the package command as not used.
- If two packages have a command with the same name, `dox <name>` prints an error with both package names and exits with code 1.
- A bad `dox: commands:` key (not a library of the package, or a missing file) prints a warning with the package name. The commands of the other packages still work.
- The key path may use only letters, digits, `_`, `-`, `.` and `/`, and no `..`.
- An unknown command prints `Could not find a command named "<name>"`, with a hint about the `dox: commands:` key.

### How it works

- `dox <name>` first looks for a built-in command. Then it reads `.dart_tool/package_config.json` and the `dox: commands:` key of each package and of the app.
- It writes `.dart_tool/dox/commands.dart`, which imports each commands library, and runs it with `dart run`. So the command code is always the newest.
- It writes that file again only when `.dart_tool/package_config.json` or a `pubspec.yaml` changes. If a package had a warning, `dox` looks again on the next run.
- `dox help` keeps the list in `.dart_tool/dox/commands.json`. If you change only a file that the commands library imports, `dox help` can show an old description. The command itself always runs the new code.
- `MigrationFile().create` finds a migration with the same name and any time in its name. `dox migrate` writes `db/migration/migrations.dart` again before it runs, and makes `bin/migrate.dart` when it is missing.
- An app inside a pub workspace works too, also when the `workspace:` list uses a glob like `apps/*`. `dox` finds the workspace root from `.dart_tool/pub/workspace_ref.json`.

## See also

- [Dox CLI](dox-cli.md): the commands of the CLI.
- [Add a package](../getting-started/add-a-package.md): `dox add` runs the install command of a package.
- [Providers](providers.md): set up a package when the app starts.
