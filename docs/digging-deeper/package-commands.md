---
icon: lucide/blocks
---

# Package commands

A package or an app can add its own `dox` commands, and the `dox` CLI finds them by itself.

## Setup

Add the package and run its command. For example, `dox queue:table` comes from the `dox_queue_database` package:

```bash
dart pub add dox_queue_database
dox queue:table
```

`dox help` lists the commands of each package, under the package name.

## Add a command to your package

A package command needs three things: the command class, a list of commands and a key in `pubspec.yaml`.

### 1. Write the command

A command extends `Command` from `package:dox_core/command.dart`. The `run` method gets the words after the command name:

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

So `dox hello:say Ann` calls `run(['Ann'])`. A package with no `dox_core` dependency imports `package:dox_annotation/command.dart`.

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

An app that depends on your package now has `dox hello:say`.

## Add a command to your app

`dox make:command` writes the command, adds it to `lib/app/commands/commands.dart` and sets the `dox: commands:` key:

```bash
dox make:command send_report
```

The command name is `app:send-report`. See [`dox make:command`](../reference/cli.md#dox-makecommand).

## Name clashes

A built-in command always wins over a package command with the same name. When two packages have a command with the same name, `dox <name>` prints an error with both package names.

## Failing a command

Set `exitCode` from `dart:io`, or throw. The exit code of the command is the exit code of `dox`:

```dart
exitCode = 1;
```

A thrown error prints its stack trace and gives exit code 1.

## Writing a migration

`MigrationFile().create` writes a migration with the same file name format as `dox make:migration`. It returns null and writes nothing when a migration with this name is already there:

```dart
String? path = MigrationFile().create('create_queue_tables', source);
if (path == null) {
  print('A create_queue_tables migration is already in db/migration.');
  exitCode = 1;
}
```

`MigrationFile().exists(name)` only tells you if the migration is there. The next `dox migrate` runs the new file.

## Ship an install command

`dox add <x>` adds the package `dox_x`, then runs its `<x>:install` command. If your package needs config files, env keys or a provider, ship an `<x>:install` command.

`Installer` from `package:dox_annotation/install.dart` does the steps. A step never overwrites a file and never adds a key twice, so it is safe to run twice:

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

| Member | What it does |
| --- | --- |
| `Installer(root: dir)` | Works in the folder `dir`. The default is the current folder. |
| `appName` | The `name` of the app `pubspec.yaml`, for `package:<app>/...` imports. |
| `writeFile(path, content)` | Writes the file only when it is not there. Returns true when it wrote it. |
| `makeFolder(path)` | Makes the folder when it is not there. |
| `addEnv(key, value)` | Adds `KEY=value` to `.env.example` and `.env` when the key is missing. |
| `addEnvGetter(getter)` | Adds a getter to `AppEnv` in `lib/config/env.dart` when the class has no member with that name. |
| `hasDependency(package)` | True when the app `pubspec.yaml` has the package. |
| `addDependency(package, dev: false)` | Runs `dart pub add` when the app does not have the package. |
| `buildRunner()` | Runs `dart run build_runner build`. |
| `note(line)` | Adds your own line to the summary, like `added    hooks to pubspec.yaml`. |
| `lines` | The lines of the summary. |
| `ok` | False when a step failed. |
| `printSummary(nextSteps)` | Prints what was done and the next steps. Sets exit code 1 when a step failed. |

Read the options from `args`, like `--driver=postgres`, and give a good default, so `dox add <x>` works with no options. `dox_orm` has an example: `orm:install`.

## Next steps

- [Dox CLI](dox-cli.md): the commands of the CLI.
- [Add a package](../getting-started/add-a-package.md): `dox add` runs the install command of a package.
- [Providers](providers.md): set up a package when the app starts.
