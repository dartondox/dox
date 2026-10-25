import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

AppConfig config = AppConfig(
  appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt',

  totalIsolate: 1,
  cache: CacheConfig(
    defaultStore: 'memory',
    stores: <String, Map<String, dynamic>>{
      'memory': <String, dynamic>{'driver': 'memory'},
      'file': <String, dynamic>{'driver': 'file', 'path': 'storage/test-cache'},
    },
  ),
  exceptionHandler: const _QuietExceptionHandler(),
);

void main() {
  setUpAll(() {
    Dox().initialize(config);
  });

  tearDownAll(() async {
    await Dox().cache.close();
    Directory dir = Directory('storage/test-cache');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group('Cache facade |', () {
    for (String store in <String>['memory', 'file']) {
      test('$store: put, get, has, forget, JSON values', () async {
        await Cache().store(store).put('name', 'Dox');
        expect(await Cache().store(store).get('name'), 'Dox');
        expect(await Cache().store(store).has('name'), isTrue);

        await Cache().store(store).put('user', <String, dynamic>{'id': 1});
        expect(await Cache().store(store).get('user'), <String, dynamic>{
          'id': 1,
        });
        expect(await Cache().store(store).getRaw('user'), '{"id":1}');
        expect(await Cache().store(store).getRaw('nope'), isNull);

        await Cache().store(store).forget('name');
        expect(await Cache().store(store).get('name'), isNull);
        expect(await Cache().store(store).get('name', 'fallback'), 'fallback');
      });

      test('$store: ttl, tags, remember, increment', () async {
        await Cache()
            .store(store)
            .put('short', 'x', duration: const Duration(milliseconds: 1));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(await Cache().store(store).get('short'), isNull);

        await Cache().store(store).tag('posts').put('p1', 'Post');
        await Cache().store(store).put('keep', 'yes');
        await Cache().store(store).tag('posts').flush();
        expect(await Cache().store(store).tag('posts').get('p1'), isNull);
        expect(await Cache().store(store).get('keep'), 'yes');

        int calls = 0;
        Future<int> compute() async => ++calls;
        expect(await Cache().store(store).rememberForever('r', compute), 1);
        expect(await Cache().store(store).rememberForever('r', compute), 1);

        expect(await Cache().store(store).increment('n', 2), 2);
        expect(await Cache().store(store).decrement('n'), 1);
      });
    }

    test('default store comes from the config', () async {
      await Cache().put('default', 'memory');
      expect(await Cache().store('memory').get('default'), 'memory');
    });
  });
}

/// does not log the errors the tests cause on purpose
class _QuietExceptionHandler extends ExceptionHandler {
  const _QuietExceptionHandler();

  @override
  void report(Object error, StackTrace stackTrace) {}
}
