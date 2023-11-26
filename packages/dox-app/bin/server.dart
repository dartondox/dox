import 'package:dox_app/config/app.dart';
import 'package:dox_app/services/auth_service.dart';
import 'package:dox_app/services/database_service.dart';
import 'package:dox_app/services/websocket_service.dart';
import 'package:dox_core/dox_core.dart';

void main() async {
  /// Initialize Dox
  Dox().initialize(Config());

  Dox().addService(DatabaseService());
  Dox().addService(AuthService());
  Dox().addService(WebsocketService());

  /// run database migration before starting server
  await DatabaseService().migrate();

  /// start dox http server
  await Dox().startServer();
}
