import 'dart:convert';
import 'dart:typed_data';

import 'package:dox_storage/dox_storage.dart';
import 'package:test/test.dart';

/// The same behaviour tests for every driver.
void runDiskContract(
  String name,
  Future<Disk> Function() createDisk, {
  Future<void> Function()? cleanUp,
}) {
  group('$name contract', () {
    late Disk disk;

    setUp(() async {
      disk = await createDisk();
      await disk.deleteAll();
    });

    tearDown(() async {
      await disk.deleteAll();
      if (cleanUp != null) {
        await cleanUp();
      }
    });

    test('put string and getString', () async {
      await disk.put('notes/hello.txt', 'hello world');
      expect(await disk.getString('notes/hello.txt'), 'hello world');
    });

    test('put bytes and get', () async {
      await disk.put('bin/data.bin', <int>[1, 2, 3, 255]);
      expect(await disk.get('bin/data.bin'), <int>[1, 2, 3, 255]);
    });

    test('put with a stream', () async {
      Stream<List<int>> stream = Stream<List<int>>.fromIterable(<List<int>>[
        utf8.encode('ab'),
        utf8.encode('cd'),
      ]);
      await disk.put('stream.txt', stream);
      expect(await disk.getString('stream.txt'), 'abcd');
    });

    test('putStream', () async {
      await disk.putStream(
        'stream2.txt',
        Stream<List<int>>.value(utf8.encode('xyz')),
      );
      expect(await disk.getString('stream2.txt'), 'xyz');
    });

    test('put overwrites', () async {
      await disk.put('a.txt', 'one');
      await disk.put('a.txt', 'two');
      expect(await disk.getString('a.txt'), 'two');
    });

    test('put rejects unknown content types', () async {
      expect(disk.put('a.txt', 42), throwsArgumentError);
    });

    test('get missing file throws FileNotFoundException', () async {
      expect(
        disk.get('missing.txt'),
        throwsA(
          isA<FileNotFoundException>()
              .having((FileNotFoundException e) => e.key, 'key', 'missing.txt'),
        ),
      );
    });

    test('getStream', () async {
      await disk.put('s.txt', 'streamed');
      Stream<List<int>> stream = await disk.getStream('s.txt');
      List<int> bytes = <int>[];
      await for (List<int> chunk in stream) {
        bytes.addAll(chunk);
      }
      expect(utf8.decode(bytes), 'streamed');
    });

    test('getStream missing file throws FileNotFoundException', () async {
      expect(disk.getStream('nope.txt'), throwsA(isA<FileNotFoundException>()));
    });

    test('getMetaData', () async {
      DateTime before = DateTime.now().subtract(const Duration(minutes: 5));
      await disk.put('meta/file.txt', '12345');
      ObjectMetaData meta = await disk.getMetaData('meta/file.txt');
      expect(meta.size, 5);
      expect(meta.contentType, startsWith('text/plain'));
      expect(meta.lastModified.isAfter(before), isTrue);
      expect(meta.etag, isNotEmpty);
    });

    test('getMetaData uses the given content type', () async {
      await disk.put(
        'meta/blob',
        Uint8List.fromList(<int>[1]),
        options: const WriteOptions(contentType: 'image/png'),
      );
      ObjectMetaData meta = await disk.getMetaData('meta/blob');
      if (disk.driver is! LocalDriver) {
        expect(meta.contentType, 'image/png');
      }
      expect(meta.size, 1);
    });

    test('getMetaData missing file throws FileNotFoundException', () async {
      expect(
        disk.getMetaData('nope.txt'),
        throwsA(isA<FileNotFoundException>()),
      );
    });

    test('exists', () async {
      expect(await disk.exists('e.txt'), isFalse);
      await disk.put('e.txt', 'x');
      expect(await disk.exists('e.txt'), isTrue);
    });

    test('delete, and delete of a missing file is fine', () async {
      await disk.put('d.txt', 'x');
      await disk.delete('d.txt');
      expect(await disk.exists('d.txt'), isFalse);
      await disk.delete('d.txt');
    });

    test('deleteAll removes only files under the prefix', () async {
      await disk.put('photos/a.jpg', 'a');
      await disk.put('photos/2024/b.jpg', 'b');
      await disk.put('photos2/c.jpg', 'c');
      await disk.put('root.txt', 'r');
      await disk.deleteAll('photos');
      expect(await disk.exists('photos/a.jpg'), isFalse);
      expect(await disk.exists('photos/2024/b.jpg'), isFalse);
      expect(await disk.exists('photos2/c.jpg'), isTrue);
      expect(await disk.exists('root.txt'), isTrue);
    });

    test('deleteAll with no prefix removes everything', () async {
      await disk.put('x/1.txt', '1');
      await disk.put('2.txt', '2');
      await disk.deleteAll();
      ListResult result =
          await disk.listAll('', const ListOptions(recursive: true));
      expect(result.objects, isEmpty);
    });

    test('copy', () async {
      await disk.put('src.txt', 'copy me');
      await disk.copy('src.txt', 'dest/copy.txt');
      expect(await disk.getString('dest/copy.txt'), 'copy me');
      expect(await disk.exists('src.txt'), isTrue);
    });

    test('copy missing file throws FileNotFoundException', () async {
      expect(
        disk.copy('missing.txt', 'b.txt'),
        throwsA(isA<FileNotFoundException>()),
      );
    });

    test('move', () async {
      await disk.put('old.txt', 'move me');
      await disk.move('old.txt', 'new/place.txt');
      expect(await disk.getString('new/place.txt'), 'move me');
      expect(await disk.exists('old.txt'), isFalse);
    });

    test('listAll lists files and folders, not recursive', () async {
      await disk.put('docs/a.txt', 'a');
      await disk.put('docs/b.txt', 'b');
      await disk.put('docs/sub/c.txt', 'c');
      ListResult result = await disk.listAll('docs');
      expect(_describe(result), <String>[
        'file:docs/a.txt',
        'file:docs/b.txt',
        'dir:docs/sub',
      ]);
      expect(result.paginationToken, isNull);
      expect(result.objects.first.name, 'a.txt');
    });

    test('listAll recursive lists only files', () async {
      await disk.put('docs/a.txt', 'a');
      await disk.put('docs/sub/c.txt', 'c');
      await disk.put('other.txt', 'o');
      ListResult result =
          await disk.listAll('docs', const ListOptions(recursive: true));
      expect(_describe(result), <String>[
        'file:docs/a.txt',
        'file:docs/sub/c.txt',
      ]);
    });

    test('listAll of a missing folder is empty', () async {
      ListResult result = await disk.listAll('nothing-here');
      expect(result.objects, isEmpty);
    });

    test('listAll paginates', () async {
      for (int i = 1; i <= 5; i++) {
        await disk.put('page/$i.txt', '$i');
      }
      List<String> seen = <String>[];
      String? token;
      int pages = 0;
      do {
        ListResult result = await disk.listAll(
          'page',
          ListOptions(recursive: true, limit: 2, paginationToken: token),
        );
        for (DriveEntry entry in result.objects) {
          seen.add(entry.key);
        }
        token = result.paginationToken;
        pages++;
      } while (token != null);
      expect(seen, <String>[
        'page/1.txt',
        'page/2.txt',
        'page/3.txt',
        'page/4.txt',
        'page/5.txt',
      ]);
      expect(pages, 3);
    });

    test('keys with spaces and unicode round trip', () async {
      await disk.put('my files/résumé (1).txt', 'ok');
      expect(await disk.getString('my files/résumé (1).txt'), 'ok');
      ListResult result = await disk.listAll('my files');
      expect(_describe(result), <String>['file:my files/résumé (1).txt']);
    });

    test('keys are normalized', () async {
      await disk.put('a//b/./c.txt', 'n');
      expect(await disk.getString('a/b/c.txt'), 'n');
    });

    test('path traversal and absolute keys are rejected', () async {
      expect(
          disk.put('../escape.txt', 'x'), throwsA(isA<InvalidKeyException>()));
      expect(
          disk.get('a/../../etc/passwd'), throwsA(isA<InvalidKeyException>()));
      expect(disk.get('/etc/passwd'), throwsA(isA<InvalidKeyException>()));
      expect(disk.get(r'..\windows'), throwsA(isA<InvalidKeyException>()));
      expect(disk.deleteAll('..'), throwsA(isA<InvalidKeyException>()));
    });
  });
}

List<String> _describe(ListResult result) {
  List<String> out = <String>[];
  for (DriveEntry entry in result.objects) {
    out.add('${entry is DriveDirectory ? 'dir' : 'file'}:${entry.key}');
  }
  return out;
}
