import 'dart:io';

import 'package:dox/src/tools/create_controller.dart';
import 'package:dox/src/tools/create_middleware.dart';
import 'package:dox/src/tools/create_migration.dart';
import 'package:dox/src/tools/create_model.dart';
import 'package:dox/src/tools/create_project.dart';
import 'package:dox/src/tools/create_request.dart';
import 'package:dox/src/tools/create_serializer.dart';
import 'package:dox/src/tools/generate_key.dart';
import 'package:dox/src/tools/help.dart';
import 'package:dox/src/tools/openapi_generate.dart';
import 'package:dox/src/tools/server_serve.dart';
import 'package:dox/src/tools/update_dox.dart';
import 'package:dox/src/utils/utils.dart';
import 'package:dox/src/version.dart';
import 'package:dox_migration/dox_migration.dart';

import 'types.dart';

/// Example of how to add a new command:
///
/// ```dart
/// CommandRegistry.addCommand(
///   CommandDefinition(
///     command: 'new:command',
///     helpInfo: 'new:command <arg1> [arg2]',
///     description: 'Description of what this command does',
///     category: CommandCategory.generation,
///     minArgs: 1,
///     maxArgs: 2,
///     aliases: ['nc', 'new'],
///     function: (args) async {
///       // Your command implementation here
///       print('Executing new command with args: $args');
///     },
///   ),
/// );
/// ```
class CommandRegistry {
  static final List<CommandDefinition> _commands = [
    // Version commands
    CommandDefinition(
      command: 'version',
      helpInfo: 'version or v',
      description: 'Show Dox version',
      category: CommandCategory.system,
      aliases: ['--version', '-version', 'v', '-v', '--v'],
      function: (args) async {
        print('Dox version: $version');
      },
    ),

    // Create project
    CommandDefinition(
      command: 'create',
      helpInfo: 'create <project_name> [--version <version>]',
      description: 'Create a new Dox project',
      category: CommandCategory.project,
      minArgs: 1,
      maxArgs: 3,
      function: (args) async {
        final projectName = args[0];
        final flag = args[1];
        bool isVersionFlag = flag == '--version' || flag == '--v';
        final version = args.length >= 3 && isVersionFlag ? args[2] : null;
        createProject(projectName, version);
      },
    ),

    // Create model
    CommandDefinition(
      command: 'create:model',
      helpInfo: 'create:model <model_name> [-m|--migration]',
      description:
          'Create a new model, and with -m a create_<table>_table migration',
      category: CommandCategory.generation,
      aliases: ['make:model'],
      minArgs: 1,
      maxArgs: 2,
      function: (args) async {
        if (args.length < 2) {
          createModel(args[0]);
          return;
        }
        if (args[1] != '-m' && args[1] != '--migration') {
          print('Invalid option ${args[1]}, use -m or --migration');
          exitCode = 1;
          return;
        }

        /// `BlogPost` => table `blog_posts`, same guess as `constrained()`
        String table = ForeignIdColumnDefinition.guessTable(
          pascalToSnake(args[0]),
        );
        if (createModel(args[0], table: table)) {
          createMigration('create_${table}_table');
        }
      },
    ),

    // Serve commands
    CommandDefinition(
      command: 'serve',
      helpInfo: 'serve or s [--ignore-build-runner]',
      description: 'Start the development server',
      category: CommandCategory.development,
      aliases: ['server', 's'],
      minArgs: 0,
      maxArgs: 1,
      function: (args) async {
        if (args.isNotEmpty && args[0] == '--ignore-build-runner') {
          serverServe();
        } else {
          watchBuilder();
          serverServe();
        }
      },
    ),

    // Build runner commands
    CommandDefinition(
      command: 'build_runner:watch',
      helpInfo: 'build_runner:watch',
      description: 'Watch and run build runner',
      category: CommandCategory.buildRunner,
      function: (args) async {
        watchBuilder();
      },
    ),

    CommandDefinition(
      command: 'build_runner:build',
      helpInfo: 'build_runner:build',
      description: 'Run build runner once',
      category: CommandCategory.buildRunner,
      function: (args) async {
        buildBuilder();
      },
    ),

    CommandDefinition(
      command: 'build',
      helpInfo: 'build',
      description: 'AOT compile the app for production into build/bundle (use this, not dart run, in production)',
      category: CommandCategory.build,
      function: (args) async {
        await buildServer();
      },
    ),

    // Update command
    CommandDefinition(
      command: 'update',
      helpInfo: 'update',
      description: 'Update Dox framework',
      category: CommandCategory.system,
      function: (args) async {
        updateDox();
      },
    ),

    // Create controller commands
    CommandDefinition(
      command: 'create:controller',
      helpInfo: 'create:controller <controller_name> [-r] [-ws]',
      description: 'Create a new controller',
      category: CommandCategory.development,
      minArgs: 1,
      maxArgs: 2,
      function: (args) async {
        final controllerName = args[0];
        final isResource = args.length >= 2 && args[1] == '-r';
        final isWebSocket = args.length >= 2 && args[1] == '-ws';

        if (isWebSocket) {
          createWsController(controllerName);
        } else {
          createController(controllerName, isResource);
        }
      },
    ),

    // Create middleware command
    CommandDefinition(
      command: 'create:middleware',
      helpInfo: 'create:middleware <middleware_name>',
      description: 'Create a new middleware',
      category: CommandCategory.development,
      minArgs: 1,
      maxArgs: 1,
      function: (args) async {
        createMiddleware(args[0]);
      },
    ),

    // Create request command
    CommandDefinition(
      command: 'create:request',
      helpInfo: 'create:request <request_name>',
      description: 'Create a new request class',
      category: CommandCategory.development,
      minArgs: 1,
      maxArgs: 1,
      function: (args) async {
        createRequest(args[0]);
      },
    ),

    // Create serializer command
    CommandDefinition(
      command: 'create:serializer',
      helpInfo: 'create:serializer <serializer_name>',
      description: 'Create a new serializer',
      category: CommandCategory.generation,
      minArgs: 1,
      maxArgs: 1,
      function: (args) async {
        createSerializer(args[0]);
      },
    ),

    // Key generation command
    CommandDefinition(
      command: 'key:generate',
      helpInfo: 'key:generate',
      description: 'Generate application key',
      category: CommandCategory.generation,
      function: (args) async {
        generateKey();
      },
    ),

    // OpenAPI
    CommandDefinition(
      command: 'openapi:generate',
      helpInfo: 'openapi:generate [dir]',
      description: 'Write openapi.json and openapi.yaml (runs bin/openapi.dart, default dir storage/openapi)',
      category: CommandCategory.generation,
      maxArgs: 1,
      function: (args) async {
        await openApiGenerate(args);
      },
    ),

    // Help command
    CommandDefinition(
      command: 'help',
      helpInfo: 'help [command]',
      description: 'Show help information',
      category: CommandCategory.system,
      minArgs: 0,
      maxArgs: 1,
      function: (args) async {
        if (args.isNotEmpty) {
          helpCommand(args[0]);
        } else {
          help();
        }
      },
    ),

    // Migration commands
    CommandDefinition(
      command: 'migration:run',
      helpInfo: 'migration:run',
      description: 'Run pending migrations',
      category: CommandCategory.database,
      aliases: ['migrate'],
      function: (args) async {
        await _migration('run', args, () => Migrator().migrate());
      },
    ),

    CommandDefinition(
      command: 'migration:rollback',
      helpInfo: 'migration:rollback [--step=<count>]',
      description:
          'Rollback the last batch, or the last <count> migrations with --step',
      category: CommandCategory.database,
      aliases: ['migrate:rollback'],
      maxArgs: 1,
      function: (args) async {
        int? step;
        if (args.isNotEmpty) {
          step = int.tryParse(args[0].replaceFirst('--step=', ''));
          if (step == null || step < 1 || !args[0].startsWith('--step=')) {
            print('Invalid option ${args[0]}, use --step=<count>');
            exitCode = 1;
            return;
          }
        }
        await _migration(
          'rollback',
          args,
          () => Migrator().rollback(step: step),
        );
      },
    ),

    CommandDefinition(
      command: 'migration:reset',
      helpInfo: 'migration:reset',
      description: 'Rollback all migrations',
      category: CommandCategory.database,
      aliases: ['migrate:reset'],
      function: (args) async {
        await _migration('reset', args, () => Migrator().reset());
      },
    ),

    CommandDefinition(
      command: 'migration:refresh',
      helpInfo: 'migration:refresh',
      description: 'Rollback all migrations and run them again',
      category: CommandCategory.database,
      aliases: ['migrate:refresh'],
      function: (args) async {
        await _migration('refresh', args, () => Migrator().refresh());
      },
    ),

    CommandDefinition(
      command: 'migration:status',
      helpInfo: 'migration:status',
      description: 'Show which migrations ran, and their batch',
      category: CommandCategory.database,
      aliases: ['migrate:status'],
      function: (args) async {
        await _migration(
          'status',
          args,
          () async => Migrator.printStatus(await Migrator().status()),
        );
      },
    ),

    CommandDefinition(
      command: 'make:migration',
      helpInfo: 'make:migration <name> [--sql]',
      description:
          'Create a Dart migration (or a .sql one with --sql) in db/migration',
      category: CommandCategory.database,
      aliases: ['create:migration'],
      minArgs: 1,
      maxArgs: 2,
      function: (args) async {
        createMigration(args[0], sql: args.length >= 2 && args[1] == '--sql');
      },
    ),
  ];

  static CommandDefinition? findCommand(String command) {
    try {
      return _commands.firstWhere((cmd) => cmd.matches(command));
    } catch (e) {
      return null;
    }
  }

  static List<CommandDefinition> getAllCommands() {
    return _commands;
  }

  static void addCommand(CommandDefinition command) {
    _commands.add(command);
  }
}

/// run a migration command.
/// - with `bin/migrate.dart` (Dart migrations): make the registry again,
///   then run `dart run bin/migrate.dart <command>`, so the app code runs.
/// - without it: run the `.sql` migrations here with [direct].
/// print the error and set exit code 1 when it fails,
/// so scripts and CI see the failure.
Future<void> _migration(
  String command,
  List<String> args,
  Future<void> Function() direct,
) async {
  if (migrateEntryFile().existsSync()) {
    writeMigrationRegistry();
    String exe = Platform.resolvedExecutable;
    String dart = exe.split(Platform.pathSeparator).last.startsWith('dart')
        ? exe
        : 'dart';
    Process process = await Process.start(dart, [
      'run',
      'bin/migrate.dart',
      command,
      ...args,
    ], mode: ProcessStartMode.inheritStdio);
    int code = await process.exitCode;
    if (code != 0) exitCode = code;
    return;
  }
  if (hasDartMigrations()) {
    print(
      'db/migration has Dart migrations, but bin/migrate.dart is missing. '
      'Run `dox make:migration <name>` once to make it, or see the docs.',
    );
    exitCode = 1;
    return;
  }
  try {
    await direct();
  } catch (error) {
    print(error);
    exitCode = 1;
  }
}
