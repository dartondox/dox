import 'dart:io';

import 'package:dox/src/command_registry.dart';
import 'package:test/test.dart';

// Helper class to capture output
class OutputCapture {
  final StringBuffer buffer = StringBuffer();

  void capture(Object? object) {
    buffer.write(object);
  }

  String get output => buffer.toString();

  void reset() {
    buffer.clear();
  }
}

void main() {
  group('CommandRegistry Tests', () {
    test('should find existing commands', () {
      final command = CommandRegistry.findCommand('help');
      expect(command, isNotNull);
      expect(command!.command, equals('help'));
    });

    test('should return null for non-existent commands', () {
      final command = CommandRegistry.findCommand('non-existent');
      expect(command, isNull);
    });

    test('should find commands by aliases', () {
      final command = CommandRegistry.findCommand('v');
      expect(command, isNotNull);
      expect(command!.command, equals('version'));
    });

    test('should validate command arguments correctly', () {
      final command = CommandRegistry.findCommand('create:model');
      expect(command, isNotNull);

      // Test valid arguments
      expect(command!.validateArgs(['User']), isTrue);

      // Test invalid arguments (too few)
      expect(command.validateArgs([]), isFalse);

      // Test invalid arguments (too many)
      expect(command.validateArgs(['User', 'extra']), isFalse);
    });

    test('should get all commands', () {
      final commands = CommandRegistry.getAllCommands();
      expect(commands, isNotEmpty);
      expect(commands.length, greaterThan(10)); // Should have many commands
    });
  });

  group('Command Execution Tests', () {
    late Directory tempDir;
    late String originalCwd;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dox_test_');
      originalCwd = Directory.current.path;
      Directory.current = tempDir;
    });

    tearDown(() {
      Directory.current = originalCwd;
      tempDir.deleteSync(recursive: true);
    });

    test('version command should print version', () {
      final command = CommandRegistry.findCommand('version');
      expect(command, isNotNull);

      // For now, just test that the command exists and can be executed
      // We'll test actual output in integration tests
      expect(() => command!.function([]), returnsNormally);
    });

    test('help command should print help information', () {
      final command = CommandRegistry.findCommand('help');
      expect(command, isNotNull);

      // For now, just test that the command exists and can be executed
      expect(() => command!.function([]), returnsNormally);
    });

    test('help command with argument should show specific command help', () {
      final command = CommandRegistry.findCommand('help');
      expect(command, isNotNull);

      // For now, just test that the command exists and can be executed
      expect(() => command!.function(['create:model']), returnsNormally);
    });
  });

  group('File Generation Tests', () {
    late Directory tempDir;
    late String originalCwd;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dox_test_');
      originalCwd = Directory.current.path;
      Directory.current = tempDir;

      // Create necessary directories
      Directory('lib/app/models').createSync(recursive: true);
      Directory('lib/app/http/controllers').createSync(recursive: true);
      Directory('lib/app/http/middleware').createSync(recursive: true);
      Directory('lib/app/http/requests').createSync(recursive: true);
      Directory('lib/app/http/serializers').createSync(recursive: true);
      Directory('lib/app/ws/controllers').createSync(recursive: true);
      Directory('db/migration').createSync(recursive: true);
    });

    tearDown(() {
      Directory.current = originalCwd;
      tempDir.deleteSync(recursive: true);
    });

    test('create:model should generate model file', () {
      final command = CommandRegistry.findCommand('create:model');
      expect(command, isNotNull);

      expect(() => command!.function(['User']), returnsNormally);

      // Check if file was created
      final modelFile = File('lib/app/models/user/user.model.dart');
      expect(modelFile.existsSync(), isTrue);

      // Check file content
      final content = modelFile.readAsStringSync();
      expect(content, contains('class User extends UserGenerator'));
      expect(content, contains('@DoxModel()'));
    });

    test('create:controller should generate controller file', () {
      final command = CommandRegistry.findCommand('create:controller');
      expect(command, isNotNull);

      expect(() => command!.function(['UserController']), returnsNormally);

      // Check if file was created
      final controllerFile =
          File('lib/app/http/controllers/user.controller.dart');
      expect(controllerFile.existsSync(), isTrue);

      // Check file content
      final content = controllerFile.readAsStringSync();
      expect(content, contains('class UserController'));
      expect(content, contains('index(DoxRequest req)'));
    });

    test(
        'create:controller with resource flag should generate resource controller',
        () {
      final command = CommandRegistry.findCommand('create:controller');
      expect(command, isNotNull);

      expect(
          () => command!.function(['UserController', '-r']), returnsNormally);

      // Check if file was created
      final controllerFile =
          File('lib/app/http/controllers/user.controller.dart');
      expect(controllerFile.existsSync(), isTrue);

      // Check file content for resource methods
      final content = controllerFile.readAsStringSync();
      expect(content, contains('index(DoxRequest req)'));
      expect(content, contains('create(DoxRequest req)'));
      expect(content, contains('store(DoxRequest req)'));
      expect(content, contains('show(DoxRequest req, String id)'));
      expect(content, contains('edit(DoxRequest req, String id)'));
      expect(content, contains('update(DoxRequest req, String id)'));
      expect(content, contains('destroy(DoxRequest req, String id)'));
    });

    test(
        'create:controller with websocket flag should generate websocket controller',
        () {
      final command = CommandRegistry.findCommand('create:controller');
      expect(command, isNotNull);

      expect(
          () => command!.function(['UserController', '-ws']), returnsNormally);

      // Check if file was created
      final controllerFile =
          File('lib/app/ws/controllers/user.controller.dart');
      expect(controllerFile.existsSync(), isTrue);

      // Check file content for websocket methods
      final content = controllerFile.readAsStringSync();
      expect(content, contains('class UserController'));
      expect(content,
          contains('index(WebsocketEmitter emitter, dynamic message)'));
      expect(content,
          contains('import \'package:dox_websocket/dox_websocket.dart\''));
    });

    test('create:middleware should generate middleware file', () {
      final command = CommandRegistry.findCommand('create:middleware');
      expect(command, isNotNull);

      expect(() => command!.function(['AuthMiddleware']), returnsNormally);

      // Check if file was created
      final middlewareFile =
          File('lib/app/http/middleware/auth.middleware.dart');
      expect(middlewareFile.existsSync(), isTrue);

      // Check file content
      final content = middlewareFile.readAsStringSync();
      expect(content, contains('class AuthMiddleware'));
      expect(content, contains('handle(IDoxRequest req)'));
    });

    test('create:request should generate request file', () {
      final command = CommandRegistry.findCommand('create:request');
      expect(command, isNotNull);

      expect(() => command!.function(['UserRequest']), returnsNormally);

      // Check if file was created
      final requestFile = File('lib/app/http/requests/user.request.dart');
      expect(requestFile.existsSync(), isTrue);

      // Check file content
      final content = requestFile.readAsStringSync();
      expect(content, contains('class UserRequest extends FormRequest'));
      expect(content, contains('Map<String, String> rules()'));
    });

    test('create:serializer should generate serializer file', () {
      final command = CommandRegistry.findCommand('create:serializer');
      expect(command, isNotNull);

      expect(() => command!.function(['UserSerializer']), returnsNormally);

      // Check if file was created
      final serializerFile =
          File('lib/app/http/serializers/user.serializer.dart');
      expect(serializerFile.existsSync(), isTrue);

      // Check file content
      final content = serializerFile.readAsStringSync();
      expect(content, contains('class UserSerializer'));
      expect(content, contains('Map<String, dynamic> convert(User m)'));
    });

    test('create:migration should generate migration file', () {
      final command = CommandRegistry.findCommand('create:migration');
      expect(command, isNotNull);

      expect(() => command!.function(['create_users_table']), returnsNormally);

      // Check if migration file was created
      final migrationFiles = Directory('db/migration')
          .listSync()
          .where((file) => file.path.contains('create_users_table'))
          .toList();

      expect(migrationFiles, isNotEmpty);
    });
  });

  group('Error Handling Tests', () {
    test('should handle invalid command gracefully', () {
      final command = CommandRegistry.findCommand('invalid_command');
      expect(command, isNull);
    });

    test('should handle invalid arguments gracefully', () {
      final command = CommandRegistry.findCommand('create:model');
      expect(command, isNotNull);

      // Test that invalid arguments are handled
      expect(command!.validateArgs([]), isFalse);
      expect(command.validateArgs(['User', 'extra']), isFalse);
    });
  });

  group('Category Tests', () {
    test('should group commands by category correctly', () {
      final commands = CommandRegistry.getAllCommands();

      // Check that commands have proper categories
      for (final command in commands) {
        expect(command.category, isA<CommandCategory>());
        expect(command.category.displayName, isNotEmpty);
        expect(command.category.order, isA<int>());
      }

      // Check that categories are properly ordered
      final categories = commands.map((c) => c.category).toSet().toList();
      categories.sort((a, b) => a.order.compareTo(b.order));

      // Verify order
      expect(categories.first.order, equals(0)); // project should be first
      expect(categories.last.order, equals(6)); // system should be last
    });

    test('should display category names correctly', () {
      expect(CommandCategory.project.displayName, equals('Project'));
      expect(CommandCategory.development.displayName, equals('Development'));
      expect(CommandCategory.generation.displayName, equals('Generation'));
      expect(CommandCategory.database.displayName, equals('Database'));
      expect(CommandCategory.system.displayName, equals('System'));
    });
  });
}
