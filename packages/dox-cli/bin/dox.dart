import 'package:dox/dox.dart';
import 'package:dox/src/tools/create_controller.dart';
import 'package:dox/src/tools/create_middleware.dart';
import 'package:dox/src/tools/create_project.dart';
import 'package:dox/src/tools/create_request.dart';
import 'package:dox/src/tools/create_serializer.dart';
import 'package:dox/src/tools/generate_key.dart';
import 'package:dox/src/tools/help.dart';
import 'package:dox/src/tools/server_serve.dart';
import 'package:dox/src/tools/update_dox.dart';
import 'package:dox_migration/dox_migration.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Could not find a command. Run `dox help` for more information.');
    return;
  }

  final command = args[0];
  final commandArgs = args.skip(1).toList();

  try {
    await _executeCommand(command, commandArgs);
  } catch (e) {
    print(e);
  }
}

Future<void> _executeCommand(String command, List<String> args) async {
  // Version commands
  if (_isVersionCommand(command)) {
    print('Dox version: 2.0.1');
    return;
  }

  // Create project commands
  if (command == 'create' && args.isNotEmpty) {
    final projectName = args[0];
    final version =
        args.length >= 3 && _isVersionFlag(args[1]) ? args[2] : null;
    createProject(projectName, version);
    return;
  }

  // Create model command
  if (command == 'create:model' && args.length == 1) {
    createModel(args[0]);
    return;
  }

  // Serve commands
  if (_isServeCommand(command)) {
    if (args.isNotEmpty && args[0] == '--ignore-build-runner') {
      serverServe();
    } else {
      watchBuilder();
      serverServe();
    }
    return;
  }

  // Build runner commands
  if (command == 'build_runner:watch') {
    watchBuilder();
    return;
  }

  if (command == 'build_runner:build') {
    buildBuilder();
    return;
  }

  if (command == 'build') {
    buildBuilder();
    buildServer();
    return;
  }

  // Update command
  if (command == 'update') {
    updateDox();
    return;
  }

  // Create controller commands
  if (command == 'create:controller' && args.isNotEmpty) {
    final controllerName = args[0];
    final isResource = args.length >= 2 && args[1] == '-r';
    final isWebSocket = args.length >= 2 && args[1] == '-ws';

    if (isWebSocket) {
      createWsController(controllerName);
    } else {
      createController(controllerName, isResource);
    }
    return;
  }

  // Create middleware command
  if (command == 'create:middleware' && args.length == 1) {
    createMiddleware(args[0]);
    return;
  }

  // Create request command
  if (command == 'create:request' && args.length == 1) {
    createRequest(args[0]);
    return;
  }

  // Create serializer command
  if (command == 'create:serializer' && args.length == 1) {
    createSerializer(args[0]);
    return;
  }

  // Key generation command
  if (command == 'key:generate') {
    generateKey();
    return;
  }

  // Help command
  if (command == 'help') {
    help();
    return;
  }

  // Migration commands
  if (command == 'migration:run' && args.isEmpty) {
    await Migration(from: 'cli').migrate();
    return;
  }

  if (command == 'migration:rollback' && args.isEmpty) {
    await Migration(from: 'cli').rollback();
    return;
  }

  if (command == 'create:migration' && args.isNotEmpty) {
    final migrationName = args[0];
    final type = args.length >= 2 ? args[1] : 'sql';
    MigrationFile(migrationName, type);
    return;
  }

  // If no command matches, throw an exception to trigger the error message
  throw Exception(
      'Could not find a command named "$command". Run `dox help` for more information.');
}

/// Check if the command is a app version command
bool _isVersionCommand(String command) {
  const versionKeys = ['--version', 'version', '-version', 'v', '-v', '--v'];
  return versionKeys.contains(command);
}

/// Check if the flag is a project version flag
bool _isVersionFlag(String flag) {
  return flag == '--version' || flag == '--v';
}

bool _isServeCommand(String command) {
  const serveKeys = ['serve', 'server', 's'];
  return serveKeys.contains(command);
}
