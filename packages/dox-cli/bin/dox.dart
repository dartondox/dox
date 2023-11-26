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
  List<String> versionKeys = [
    '--version',
    'version',
    '-version',
    'v',
    '-v',
    '--v'
  ];

  if (args.length == 1 && versionKeys.contains(args[0])) {
    print('Dox version: 1.1.1');
    return;
  }

  if (args.length == 2 && args[0] == 'create') {
    createProject(args[1]);
    return;
  }

  if (args.length == 2 && args[0] == 'create:migration') {
    MigrationFile(args[1], 'sql');
    return;
  }

  if (args.length == 3 && args[0] == 'create:migration') {
    MigrationFile(args[1], args[2]);
    return;
  }

  if (args.length == 2 && args[0] == 'create:model') {
    createModel(args[1]);
    return;
  }

  if (args.length == 3 && args[0] == 'create:model' && args[2] == '-m') {
    bool shouldCreateMigration = createModel(args[1]);
    if (shouldCreateMigration) {
      MigrationFile('Create${args[1]}Table', 'sql');
    }
    return;
  }

  if (args.length == 1 && args[0] == 'migrate') {
    await Migration(from: 'cli').migrate();
    return;
  }

  if (args.length == 1 && args[0] == 'migrate:rollback') {
    await Migration(from: 'cli').rollback();
    return;
  }

  List<String> serveKeys = [
    'serve',
    'server',
    's',
  ];

  if (args.length == 1 && serveKeys.contains(args[0])) {
    watchBuilder();
    serverServe();
    return;
  }

  if (args.length == 2 &&
      serveKeys.contains(args[0]) &&
      args[1] == '--ignore-build-runner') {
    serverServe();
    return;
  }

  if (args.length == 1 && args[0] == 'build_runner:watch') {
    watchBuilder();
    return;
  }

  if (args.length == 1 && args[0] == 'build_runner:build') {
    buildBuilder();
    return;
  }

  if (args.length == 1 && args[0] == 'build') {
    buildBuilder();
    buildServer();
    return;
  }

  if (args.length == 1 && args[0] == 'update') {
    updateDox();
    return;
  }

  if (args.length == 2 && args[0] == 'create:controller') {
    createController(args[1], false);
    return;
  }

  if (args.length == 2 && args[0] == 'create:middleware') {
    createMiddleware(args[1]);
    return;
  }

  if (args.length == 2 && args[0] == 'create:request') {
    createRequest(args[1]);
    return;
  }

  if (args.length == 2 && args[0] == 'create:serializer') {
    createSerializer(args[1]);
    return;
  }

  if (args.length == 3 && args[0] == 'create:controller' && args[2] == '-r') {
    createController(args[1], true);
    return;
  }

  if (args.length == 3 && args[0] == 'create:controller' && args[2] == '-ws') {
    createWsController(args[1]);
    return;
  }

  if (args.length == 1 && args[0] == 'key:generate') {
    generateKey();
    return;
  }

  if (args.length == 1 && args[0] == 'help') {
    help();
    return;
  }

  print(
      'Could not find a command named "${args[0]}". Run `dox help` for more information.');
}
