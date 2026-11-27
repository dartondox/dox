import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/http/http_static_handler.dart';
import 'package:dox_core/isolate/compute_pool.dart';
import 'package:dox_core/isolate/isolate_handler.dart';
import 'package:dox_core/isolate/isolate_interfaces.dart';
import 'package:dox_core/isolate/isolate_spawner.dart';
import 'package:dox_core/middleware/rate_limit_counter.dart';
import 'package:dox_core/router/route_data.dart';
import 'package:dox_core/session/session_memory_store.dart';

class DoxIsolate extends IsolateSpawner {
  /// singleton
  static final DoxIsolate _singleton = DoxIsolate._internal();
  factory DoxIsolate() => _singleton;
  DoxIsolate._internal();

  /// routes added before `startServer()`. router routes are not in here,
  /// each isolate registers those itself. kept so a restart gets the same.
  List<RouteData> _baseRoutes = <RouteData>[];

  /// `Route.fallback` routes added before `startServer()`, like [_baseRoutes]
  List<RouteData> _baseFallbacks = <RouteData>[];

  /// `Route.staticFiles` folders added before `startServer()`, like
  /// [_baseRoutes]
  List<StaticFolder> _baseStatics = <StaticFolder>[];

  /// create threads
  /// ```
  /// await DoxIsolate().spawn(3)
  /// ```
  @override
  Future<void> spawn(int count) async {
    stopped = false;
    _baseRoutes = List<RouteData>.of(Route().routes);
    _baseFallbacks = List<RouteData>.of(Route().fallbacks);
    _baseStatics = List<StaticFolder>.of(Route().statics);
    for (int i = 1; i < count; i++) {
      await spawnOne(i + 1);
    }
  }

  @override
  Future<Isolate> start(
    int isolateId,
    SendPort control,
    SendPort error,
    SendPort exit,
    List<ReceivePort> ports,
  ) {
    return Isolate.spawn(
      isolateHandler,
      IsolateSpawnParameter(
        isolateId,
        Dox().config,
        Dox().doxProviders,
        routes: _baseRoutes,
        fallbacks: _baseFallbacks,
        statics: _baseStatics,
        bindings: Route().bindings,
        control: control,
        rateLimitPort: RateLimitCounter.instance.port,
        sessionPort: SessionMemoryStore.instance.port,
        busPort: IsolateBus.instance.port,
        computePort: ComputePool.instance.port,
        isolateCount: Dox().isolateCount,
        envExpand: Env().expanded,
      ),
      onError: error,
      onExit: exit,
    );
  }
}
