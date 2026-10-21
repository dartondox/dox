import 'dart:io';

import 'package:dox_cache/dox_cache.dart';
import 'package:test/test.dart';

class CountingFactory implements CacheDriverFactory {
  int created = 0;

  @override
  CacheDriver create(Map<String, dynamic> options) {
    created++;
    return MemoryDriver(prefix: options['prefix'] as String);
  }
}

void main() {
  late Directory directory;
  late CacheManager manager;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('dox_cache_manager_');
    manager = CacheManager(CacheConfig(
      defaultStore: 'memory',
      stores: <String, Map<String, dynamic>>{
        'memory': <String, dynamic>{'driver': 'memory', 'max_size': 10},
        'file': <String, dynamic>{'driver': 'file', 'path': directory.path},
        'off': <String, dynamic>{'driver': 'null'},
        'custom': <String, dynamic>{'driver': 'counting', 'prefix': 'c:'},
        'broken': <String, dynamic>{'driver': 'nope'},
      },
    ));
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('default store is the configured one', () async {
    expect(manager.store().driver, isA<MemoryDriver>());
    expect((manager.store().driver as MemoryDriver).maxSize, 10);
  });

  test('named stores are built once', () async {
    expect(manager.store('file').driver, isA<FileDriver>());
    expect(identical(manager.store('file'), manager.store('file')), isTrue);
    await manager.store('file').put('a', 1);
    expect(await manager.store('file').get('a'), 1);
  });

  test('null store never keeps values', () async {
    await manager.store('off').put('a', 1);
    expect(await manager.store('off').get('a'), isNull);
  });

  test('custom driver with extend', () async {
    CountingFactory factory = CountingFactory();
    manager.extend('counting', factory);
    await manager.store('custom').put('a', 1);
    expect(await manager.store('custom').get('a'), 1);
    expect(manager.store('custom').driver.prefix, 'c:');
    expect(factory.created, 1);
  });

  test('addStore uses a ready driver', () async {
    MemoryDriver driver = MemoryDriver();
    manager.addStore('ready', driver);
    expect(identical(manager.store('ready').driver, driver), isTrue);
  });

  test('unknown store or driver throws', () {
    expect(() => manager.store('missing'), throwsArgumentError);
    expect(() => manager.store('broken'), throwsArgumentError);
  });
}
