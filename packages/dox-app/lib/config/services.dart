import 'package:dox_app/services/auth_service.dart';
import 'package:dox_app/services/database_service.dart';
import 'package:dox_app/services/websocket_service.dart';
import 'package:dox_core/dox_core.dart';

List<DoxService> services = <DoxService>[
  DatabaseService(),
  AuthService(),
  WebsocketService(),
];
