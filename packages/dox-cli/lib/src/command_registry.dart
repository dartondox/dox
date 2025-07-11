import 'package:dox/src/tools/create_controller.dart';
import 'package:dox/src/tools/create_middleware.dart';
import 'package:dox/src/tools/create_model.dart';
import 'package:dox/src/tools/create_project.dart';
import 'package:dox/src/tools/create_request.dart';
import 'package:dox/src/tools/create_serializer.dart';
import 'package:dox/src/tools/generate_key.dart';
import 'package:dox/src/tools/help.dart';
import 'package:dox/src/tools/server_serve.dart';
import 'package:dox/src/tools/update_dox.dart';
import 'package:dox/src/version.dart';
import 'package:dox_migration/dox_migration.dart';

import 'types.dart';

/// Example of how to add a new command:
///
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
      helpInfo: 'create:model <model_name>',
      description: 'Create a new model',
      category: CommandCategory.generation,
      minArgs: 1,
      maxArgs: 1,
      function: (args) async {
        createModel(args[0]);
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
      description: 'Build the application',
      category: CommandCategory.build,
      function: (args) async {
        buildBuilder();
        buildServer();
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
      function: (args) async {
        await Migration(from: 'cli').migrate();
      },
    ),

    CommandDefinition(
      command: 'migration:rollback',
      helpInfo: 'migration:rollback',
      description: 'Rollback the last migration',
      category: CommandCategory.database,
      function: (args) async {
        await Migration(from: 'cli').rollback();
      },
    ),

    CommandDefinition(
      command: 'create:migration',
      helpInfo: 'create:migration <migration_name> [--sql|--dart]',
      description: 'Create a new migration',
      category: CommandCategory.database,
      minArgs: 1,
      maxArgs: 2,
      function: (args) async {
        final migrationName = args[0];
        final type = args.length >= 2 ? args[1] : 'sql';
        MigrationFile(migrationName, type);
      },
    ),
  ];

  static CommandDefinition? findCommand(String command) {
    try {
      return _commands.firstWhere(
        (cmd) => cmd.matches(command),
      );
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
