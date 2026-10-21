import 'dart:io';

import 'package:dox/src/command_registry.dart';
import 'package:dox/src/tools/create_controller.dart';
import 'package:dox/src/tools/create_middleware.dart';
import 'package:dox/src/tools/create_model.dart';
import 'package:dox/src/tools/create_dto.dart';
import 'package:dox/src/tools/create_serializer.dart';
import 'package:test/test.dart';

/// Generators write relative to the current directory,
/// so each test runs inside its own temp dir.
void main() {
  late Directory tempDir;
  late Directory originalCwd;

  setUp(() {
    originalCwd = Directory.current;
    tempDir = Directory.systemTemp.createTempSync('dox_gen_test_');
    Directory.current = tempDir;
  });

  tearDown(() {
    Directory.current = originalCwd;
    tempDir.deleteSync(recursive: true);
  });

  String read(String path) => File(path).readAsStringSync();

  group('generators | multi-word names', () {
    test('controller', () {
      expect(createController('BlogPostController', false), isTrue);
      String c = read('lib/app/http/controllers/blog_post.controller.dart');
      expect(c, contains('class BlogPostController {'));
      expect(c, contains('BlogPostController blogPostController ='));
    });

    test('websocket controller', () {
      expect(createWsController('ChatRoomController'), isTrue);
      String c = read('lib/app/ws/controllers/chat_room.controller.dart');
      expect(c, contains('class ChatRoomController {'));
    });

    test('model', () {
      expect(createModel('BlogPost'), isTrue);
      String c = read('lib/app/models/blog_post/blog_post.model.dart');
      expect(c, contains("part 'blog_post.model.g.dart';"));
      expect(c, contains('class BlogPost extends BlogPostGenerator {'));
    });

    test('model from snake case name', () {
      expect(createModel('blog_post'), isTrue);
      String c = read('lib/app/models/blog_post/blog_post.model.dart');
      expect(c, contains('class BlogPost extends BlogPostGenerator {'));
    });

    test('middleware', () {
      expect(createMiddleware('RateLimitMiddleware'), isTrue);
      String c = read('lib/app/http/middleware/rate_limit.middleware.dart');
      expect(c, contains('class RateLimitMiddleware extends IDoxMiddleware'));
      expect(c, contains('return req;'));
    });

    test('dto', () {
      expect(createDto('CreateBlogPost'), isTrue);
      String c = read('lib/app/http/dtos/create_blog_post.dto.dart');
      expect(c, contains('@Dto()'));
      expect(c, contains('class CreateBlogPost {'));
      expect(c, contains("part 'create_blog_post.dto.g.dart';"));
      expect(
        c,
        contains(
          r'static const DtoSchema<CreateBlogPost> schema = $CreateBlogPostDto;',
        ),
      );
    });

    test('serializer imports the matching model', () {
      expect(createSerializer('BlogPostSerializer'), isTrue);
      String c = read('lib/app/http/serializers/blog_post.serializer.dart');
      expect(
        c,
        contains('class BlogPostSerializer extends Serializer<BlogPost>'),
      );
      expect(
        c,
        contains("'../../../app/models/blog_post/blog_post.model.dart'"),
      );
    });
  });

  group('generators | existing file is not overwritten', () {
    test('controller', () {
      createController('User', false);
      File f = File('lib/app/http/controllers/user.controller.dart');
      f.writeAsStringSync('// mine');
      expect(createController('User', true), isFalse);
      expect(f.readAsStringSync(), '// mine');
    });

    test('model', () {
      expect(createModel('User'), isTrue);
      expect(createModel('User'), isFalse);
    });

    test('middleware, dto, serializer', () {
      expect(createMiddleware('Auth'), isTrue);
      expect(createMiddleware('Auth'), isFalse);
      expect(createDto('User'), isTrue);
      expect(createDto('User'), isFalse);
      expect(createSerializer('User'), isTrue);
      expect(createSerializer('User'), isFalse);
    });
  });

  group('create:model -m', () {
    List<String> migrationFiles() =>
        Directory('db/migration')
            .listSync()
            .map((FileSystemEntity f) => f.uri.pathSegments.last)
            .toList()
          ..sort();

    test('-m makes the model and a create_<plural>_table migration', () async {
      await CommandRegistry.findCommand('create:model')!
          .function(<String>['BlogPost', '-m']);
      String model = read('lib/app/models/blog_post/blog_post.model.dart');
      expect(model, contains("@DoxModel(table: 'blog_posts')"));
      List<String> files = migrationFiles();
      expect(files, contains('migrations.dart'));
      String name = files.firstWhere(
        (String f) => f.endsWith('_create_blog_posts_table.dart'),
      );
      String c = read('db/migration/$name');
      expect(c, contains("await schema.create('blog_posts', (Table table) {"));
      expect(
        read('db/migration/migrations.dart'),
        contains('CreateBlogPostsTable()'),
      );
      expect(File('bin/migrate.dart').existsSync(), isTrue);
    });

    test('make:model and --migration work too', () async {
      expect(
        CommandRegistry.findCommand('make:model')?.command,
        'create:model',
      );
      await CommandRegistry.findCommand('make:model')!
          .function(<String>['Category', '--migration']);
      expect(
        migrationFiles().any(
          (String f) => f.endsWith('_create_categories_table.dart'),
        ),
        isTrue,
      );
    });

    test('without -m: no migration, default table', () async {
      await CommandRegistry.findCommand('create:model')!
          .function(<String>['User']);
      expect(
        read('lib/app/models/user/user.model.dart'),
        contains('@DoxModel()'),
      );
      expect(Directory('db').existsSync(), isFalse);
    });

    test('unknown flag makes nothing', () async {
      await CommandRegistry.findCommand('create:model')!
          .function(<String>['User', '-x']);
      exitCode = 0;
      expect(Directory('lib').existsSync(), isFalse);
    });
  });

  group('make:migration', () {
    Future<List<File>> run(List<String> args) async {
      await CommandRegistry.findCommand('make:migration')!.function(args);
      return Directory('db/migration').listSync().whereType<File>().toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
    }

    String fileName(File f) => f.uri.pathSegments.last;

    test('create_x_table: a Dart migration that creates table x', () async {
      List<File> files = await run(<String>['create_users_table']);
      File migration = files.firstWhere(
        (File f) => fileName(f) != 'migrations.dart',
      );
      expect(
        fileName(migration),
        matches(RegExp(r'^\d{4}_\d{2}_\d{2}_\d{6}_create_users_table\.dart$')),
      );
      String c = migration.readAsStringSync();
      expect(c, contains('class CreateUsersTable extends Migration {'));
      expect(c, contains("await schema.create('users', (Table table) {"));
      expect(c, contains('table.id();'));
      expect(c, contains("await schema.dropIfExists('users');"));
    });

    test('add_y_to_x_table: a Dart migration that changes table x', () async {
      List<File> files = await run(<String>['add_avatar_to_users_table']);
      String c = files
          .firstWhere((File f) => fileName(f) != 'migrations.dart')
          .readAsStringSync();
      expect(c, contains('class AddAvatarToUsersTable extends Migration {'));
      expect(c, contains("await schema.table('users', (Table table) {"));
    });

    test('other names get an empty migration', () async {
      List<File> files = await run(<String>['SeedThings']);
      String c = files
          .firstWhere((File f) => fileName(f) != 'migrations.dart')
          .readAsStringSync();
      expect(c, contains('class SeedThings extends Migration {'));
    });

    test('registry lists the Dart migrations sorted by name', () async {
      Directory('db/migration').createSync(recursive: true);
      File('db/migration/2020_01_02_000000_b.dart')
          .writeAsStringSync('class B extends Migration {}');
      File('db/migration/2020_01_01_000000_a.dart')
          .writeAsStringSync('class A extends Migration {}');
      File('db/migration/2020_01_01_000000_skip.sql').writeAsStringSync('');
      await run(<String>['create_posts_table']);
      String registry = read('db/migration/migrations.dart');
      expect(registry, contains("import '2020_01_01_000000_a.dart' as m1;"));
      expect(registry, contains("import '2020_01_02_000000_b.dart' as m2;"));
      expect(registry, contains("    '2020_01_01_000000_a',\n    m1.A(),\n"));
      expect(registry, contains("    '2020_01_02_000000_b',\n    m2.B(),\n"));
      expect(registry, contains('m3.CreatePostsTable()'));
      expect(registry, isNot(contains('skip')));
      expect(registry, isNot(contains('migrations.dart')));
    });

    test('makes bin/migrate.dart once', () async {
      await run(<String>['create_a_table']);
      expect(
        read('bin/migrate.dart'),
        contains('Migrator(migrations: migrations)'),
      );
      File('bin/migrate.dart').writeAsStringSync('// mine');
      await run(<String>['create_b_table']);
      expect(read('bin/migrate.dart'), '// mine');
    });

    test('--sql flag writes a sql file, no registry', () async {
      List<File> files = await run(<String>['add_index', '--sql']);
      expect(files.single.path, endsWith('add_index.sql'));
      String c = files.single.readAsStringSync();
      expect(c, contains('-- up'));
      expect(c, contains('-- down'));
      expect(File('bin/migrate.dart').existsSync(), isFalse);
    });

    test('create:migration is an alias', () {
      expect(
        CommandRegistry.findCommand('create:migration')?.command,
        'make:migration',
      );
    });

    test('creates the db/migration folder when missing', () async {
      expect(Directory('db').existsSync(), isFalse);
      await run(<String>['first']);
      expect(Directory('db/migration').existsSync(), isTrue);
    });
  });

  group('dox binary', () {
    test('make files through the real cli in a temp dir', () async {
      String bin = '${originalCwd.path}/bin/dox.dart';
      ProcessResult r = await Process.run(Platform.resolvedExecutable, <String>[
        'run',
        bin,
        'create:model',
        'Post',
      ], workingDirectory: tempDir.path);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(
        File('${tempDir.path}/lib/app/models/post/post.model.dart')
            .existsSync(),
        isTrue,
      );
    });
  });
}
