import 'dart:isolate';

import 'package:dox_core/dox_core.dart';

class IsolateSpawnParameter {
  final SendPort sendPort;
  final int isolateId;
  final AppConfig config;
  final List<DoxService> services;
  final Guard? authGuard;
  const IsolateSpawnParameter(
    this.isolateId,
    this.sendPort,
    this.config,
    this.services, {
    this.authGuard,
  });
}
