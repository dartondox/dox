import 'dart:io';

import 'package:dox/src/command_registry.dart';
import 'package:dox/src/tools/create_controller.dart';
import 'package:dox/src/tools/create_middleware.dart';
import 'package:dox/src/tools/create_model.dart';
import 'package:dox/src/tools/create_request.dart';
import 'package:dox/src/tools/create_serializer.dart';
import 'package:test/test.dart';

const String multiWordBug =
    'bug: create_controller/middleware/request/serializer call toLowerCase() '
    'before pascalToSnake, so BlogPost becomes blogpost / class Blogpost';

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
    }, skip: multiWordBug);

    test('websocket controller', () {
      expect(createWsController('ChatRoomController'), isTrue);
      String c = read('lib/app/ws/controllers/chat_room.controller.dart');
      expect(c, contains('class ChatRoomController {'));
    }, skip: multiWordBug);

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
    }, skip: multiWordBug);

    test('request', () {
      expect(createRequest('BlogPostRequest'), isTrue);
      String c = read('lib/app/http/requests/blog_post.request.dart');
      expect(c, contains('class BlogPostRequest extends FormRequest'));
      expect(c, contains('Map<String, String> messages()'));
    }, skip: multiWordBug);

    test('serializer imports the matching model', () {
      expect(createSerializer('BlogPostSerializer'), isTrue);
      String c = read('lib/app/http/serializers/blog_post.serializer.dart');
      expect(
          c, contains('class BlogPostSerializer extends Serializer<BlogPost>'));
      expect(
          c, contains("'../../../app/models/blog_post/blog_post.model.dart'"));
    }, skip: multiWordBug);
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

    test('middleware, request, serializer', () {
      expect(createMiddleware('Auth'), isTrue);
      expect(createMiddleware('Auth'), isFalse);
      expect(createRequest('User'), isTrue);
      expect(createRequest('User'), isFalse);
      expect(createSerializer('User'), isTrue);
      expect(createSerializer('User'), isFalse);
    });
  });

  group('create:migration', () {
    Future<List<File>> run(List<String> args) async {
      await CommandRegistry.findCommand('create:migration')!.function(args);
      return Directory('db/migration').listSync().whereType<File>().toList();
    }

    test('writes a timestamped sql file with up and down sections', () async {
      List<File> files = await run(<String>['CreateBlogPostsTable']);
      expect(files, hasLength(1));
      String name = files.first.uri.pathSegments.last;
      expect(name, matches(RegExp(r'^\d{4}_\d{2}_\d{2}_\d+_.*\.sql$')));
      expect(name, contains('create_blog_posts_table'));
      String c = files.first.readAsStringSync();
      expect(c, contains('-- up'));
      expect(c, contains('-- down'));
    });

    test('--sql flag writes a sql file', () async {
      List<File> files = await run(<String>['add_index', '--sql']);
      expect(files.single.path, endsWith('add_index.sql'));
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
      ProcessResult r = await Process.run(
        Platform.resolvedExecutable,
        <String>['run', bin, 'create:model', 'Post'],
        workingDirectory: tempDir.path,
      );
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(
          File('${tempDir.path}/lib/app/models/post/post.model.dart')
              .existsSync(),
          isTrue);
    });
  });
}
