import 'dart:isolate';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/route_data.dart';

class IsolateSpawnParameter {
  final int isolateId;
  final AppConfig config;
  final List<DoxService> services;
  final List<RouteData> routes;

  /// the isolate sends its own [SendPort] here once it serves requests.
  /// The main isolate sends a stop message to it on shutdown.
  final SendPort? control;

  const IsolateSpawnParameter(
    this.isolateId,
    this.config,
    this.services, {
    this.routes = const <RouteData>[],
    this.control,
  });
}
