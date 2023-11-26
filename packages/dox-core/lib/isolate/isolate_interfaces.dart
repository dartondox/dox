import 'package:dox_core/dox_core.dart';
import 'package:dox_core/router/route_data.dart';

class IsolateSpawnParameter {
  final int isolateId;
  final AppConfig config;
  final List<DoxService> services;
  final List<RouteData> routes;

  const IsolateSpawnParameter(
    this.isolateId,
    this.config,
    this.services, {
    this.routes = const <RouteData>[],
  });
}
