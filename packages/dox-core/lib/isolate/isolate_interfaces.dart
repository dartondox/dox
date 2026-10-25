import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/route_data.dart';

class IsolateSpawnParameter {
  final int isolateId;
  final AppConfig config;
  final List<DoxProvider> providers;
  final List<RouteData> routes;

  /// binders from `Route.bind`
  final Map<String, RouteBinding> bindings;

  /// the isolate sends its own [SendPort] here once it serves requests.
  /// The main isolate sends a stop message to it on shutdown.
  final SendPort? control;

  const IsolateSpawnParameter(
    this.isolateId,
    this.config,
    this.providers, {
    this.routes = const <RouteData>[],
    this.bindings = const <String, RouteBinding>{},
    this.control,
  });
}
