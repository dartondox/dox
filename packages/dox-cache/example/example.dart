import 'package:dox_cache/dox_cache.dart';

Future<void> main() async {
  CacheManager cache = CacheManager(const CacheConfig(
    defaultStore: 'memory',
    stores: <String, Map<String, dynamic>>{
      'memory': <String, dynamic>{'driver': 'memory', 'max_size': 1000},
      'file': <String, dynamic>{'driver': 'file', 'path': 'storage/cache'},
      'redis': <String, dynamic>{
        'driver': 'redis',
        'host': '127.0.0.1',
        'port': 6379,
        'prefix': 'my_app:',
      },
    },
  ));

  CacheStore store = cache.store();
  await store.put(
      'user:1', <String, dynamic>{'name': 'Ann'}, const Duration(minutes: 10));
  print(await store.get('user:1'));

  int views = await store.increment('views');
  print('views: $views');

  String report =
      await store.remember<String>('report', const Duration(hours: 1), build);
  print(report);

  CacheLock lock = store.lock('daily-job', const Duration(seconds: 30));
  if (await lock.get()) {
    try {
      print('only one worker runs this');
    } finally {
      await lock.release();
    }
  }

  await store.tags(<String>['users']).put('u1', 'Ann');
  await store.tags(<String>['users']).flush();
}

Future<String> build() async {
  return 'expensive report';
}
