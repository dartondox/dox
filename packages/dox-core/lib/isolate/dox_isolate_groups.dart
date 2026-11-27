import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/isolate/group_identity.dart';
import 'package:dox_core/isolate/isolate_spawner.dart';
import 'package:dox_core/middleware/rate_limit_counter.dart';
import 'package:dox_core/session/session_memory_store.dart';

/// Like `DoxIsolate`, but every server isolate runs in its own isolate
/// group, so it has its own heap and its own garbage collector.
/// Used when `CoreFlags.isolateGroups` is on.
///
/// The isolate starts the `main()` of the app again from `snapshot`. In
/// `startServer()` it sees it is a group worker (see `GroupIdentity`),
/// asks this isolate for its ports and serves requests. So the routes,
/// config and providers are built by `main()` in each group, and nothing
/// but simple data crosses between groups. The compute pool is not
/// shared: each group has its own.
class DoxIsolateGroups extends IsolateSpawner {
  DoxIsolateGroups(this.snapshot);

  /// the file to start, see `SnapshotLocator`
  final Uri snapshot;

  /// The most time the isolates have to serve after their start, all
  /// together. `main()` of the app and the boot of the providers run in
  /// this time. After it, [spawn] fails.
  static Duration startTimeout = const Duration(seconds: 60);

  /// create the isolates 2 to [count]
  /// ```
  /// await DoxIsolateGroups(snapshot).spawn(3)
  /// ```
  @override
  Future<void> spawn(int count) async {
    stopped = false;
    firstStart = true;
    try {
      for (int i = 1; i < count; i++) {
        await spawnOne(i + 1);
      }
      // a group runs `main()` of the app. When that does not reach
      // `startServer()`, the isolate ends and the caller must know.
      // one time limit for all of them, they start at the same time
      DateTime end = DateTime.now().add(startTimeout);
      for (int id = 2; id <= count; id++) {
        // null: it ended, and it could not start again
        Completer<bool>? isReady = ready[id];
        bool serves = false;
        if (isReady != null) {
          Duration left = end.difference(DateTime.now());
          try {
            serves = await isReady.future.timeout(
              left.isNegative ? Duration.zero : left,
            );
          } on TimeoutException {
            throw IsolateSpawnException(
              'isolate $id did not serve in ${startTimeout.inSeconds} '
              'seconds. main() must reach startServer() in every isolate',
            );
          }
        }
        if (!serves) {
          throw IsolateSpawnException(
            'isolate $id ended before it served. See its error above. '
            'main() must reach startServer() in every isolate',
          );
        }
      }
    } finally {
      firstStart = false;
    }
  }

  /// a group that can not start is not tried for ever
  @override
  int? get maxEarlyExits => 3;

  @override
  Future<Isolate> start(
    int isolateId,
    SendPort control,
    SendPort error,
    SendPort exit,
    List<ReceivePort> ports,
  ) {
    ReceivePort hello = ReceivePort();
    ports.add(hello);
    hello.listen((dynamic worker) {
      hello.close();
      (worker as SendPort).send(<Object?>[
        control,
        RateLimitCounter.instance.port,
        SessionMemoryStore.instance.port,
        IsolateBus.instance.port,
      ]);
    });
    GroupIdentity identity = GroupIdentity(
      isolateId,
      Dox().isolateCount,
      hello.sendPort.nativePort,
    );
    return Isolate.spawnUri(
      snapshot,
      <String>[],
      null,
      debugName: identity.debugName,
      onError: error,
      onExit: exit,
    );
  }
}
