import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/middleware/rate_limit_counter.dart';
import 'package:dox_core/session/session_memory_store.dart';

/// An app that runs with `CoreFlags.isolateGroups` for the test of the
/// isolate groups. The settings are in the environment (GROUPS_PORT,
/// GROUPS_ISOLATES, GROUPS_KEY), because the isolates do not get the arguments.
///
/// The primary isolate prints what it sees from the other isolates:
/// `ready`, `size`, `pongs`, `boot` and `session` lines.
void main() async {
  // GROUPS_BROKEN: an app where `main()` of an isolate group does not
  // reach `startServer()`
  if (Platform.environment['GROUPS_BROKEN'] == '1' &&
      (Isolate.current.debugName ?? '').startsWith('dox-group-')) {
    return;
  }
  Dox().initialize(
    AppConfig(
      // each isolate builds the config, so the key must be the same in all
      appKey: Platform.environment['GROUPS_KEY']!,
      serverPort: int.parse(Platform.environment['GROUPS_PORT']!),
      host: '127.0.0.1',
      totalIsolate: int.parse(Platform.environment['GROUPS_ISOLATES']!),
      flags: const CoreFlags(isolateGroups: true),
      routers: <Router>[GroupsRouter()],
      providers: <DoxProvider>[GroupsProvider()],
      session: const SessionConfig(driver: 'cache', store: 'memory'),
      cache: const CacheConfig(
        defaultStore: 'memory',
        stores: <String, Map<String, dynamic>>{
          'memory': <String, dynamic>{'driver': 'memory'},
        },
      ),
    ),
  );
  // isolateId is right before startServer
  stdout.writeln('start ${Dox().isolateId} ${Dox().isPrimary}');
  await Dox().startServer();
  if (!Dox().isPrimary) return;
  await GroupsProbe().run(Dox().isolateCount);
}

class GroupsRouter extends Router {
  @override
  void register() {
    Route.get('/id', (DoxRequest req) => '${Dox().isolateId}');
    Route.get('/name', (DoxRequest req) => Isolate.current.debugName ?? '');
    Route.get('/limited', <dynamic>[
      RateLimit(max: 5, per: const Duration(minutes: 5)),
      (DoxRequest req) => 'ok',
    ]);
    Route.get('/put', <dynamic>[
      const SessionMiddleware(),
      (DoxRequest req) {
        req.session.put('name', 'ann');
        return 'ok';
      },
    ]);
    Route.get('/get', <dynamic>[
      const SessionMiddleware(),
      (DoxRequest req) => '${Dox().isolateId}:${req.session.get('name')}',
    ]);
  }
}

/// every other isolate: uses the counter, the session store and the bus
/// of the primary isolate
class GroupsProvider extends DoxProvider {
  @override
  void setup() {}

  @override
  Future<void> boot() async {
    if (Dox().isPrimary) return;
    int id = Dox().isolateId;
    await RateLimitCounter.instance.increment(
      'boot',
      const Duration(minutes: 5),
    );
    SessionMemoryStore store = SessionMemoryStore.instance;
    await store.put(null, 'boot:$id', <String, dynamic>{
      'id': id,
    }, const Duration(minutes: 5));
    Object? back = await store.get(null, 'boot:$id');
    if (back is! Map || back['id'] != id) throw StateError('bad session');
    IsolateBus.instance.on('ping').listen((Object? _) {
      IsolateBus.instance.publish('pong', <Object>[
        id,
        Isolate.current.debugName ?? '',
      ]);
    });
  }

  @override
  void shutdown() {
    stdout.writeln('cleanup ${Dox().isolateId}');
  }
}

/// what the primary isolate checks after the start
class GroupsProbe {
  Future<void> run(int count) async {
    Map<int, String> pongs = <int, String>{};
    IsolateBus.instance.on('pong').listen((Object? m) {
      List<Object?> pong = m as List<Object?>;
      pongs[pong[0] as int] = pong[1] as String;
    });
    // wait until all the other isolates joined the bus
    for (int i = 0; i < 600 && IsolateBus.instance.size < count; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    stdout.writeln('size ${IsolateBus.instance.size}');
    for (int i = 0; i < 100 && pongs.length < count - 1; i++) {
      IsolateBus.instance.publish('ping', 1);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    List<int> ids = pongs.keys.toList()..sort();
    stdout.writeln('pongs ${ids.join(',')}');
    stdout.writeln(
      'names ${pongs.values.every((String n) => n.startsWith('dox-group-'))}',
    );
    // the other isolates counted once each, this is one more
    int hits = await RateLimitCounter.instance.increment(
      'boot',
      const Duration(minutes: 5),
    );
    stdout.writeln('boot $hits');
    List<int> saved = <int>[];
    for (int id = 2; id <= count; id++) {
      Object? value = await Dox().cache.store('memory').get('boot:$id');
      if (value is Map && value['id'] == id) saved.add(id);
    }
    stdout.writeln('session ${saved.join(',')}');
  }
}
