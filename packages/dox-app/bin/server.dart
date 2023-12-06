import 'package:dox_app/config/app.dart';
import 'package:dox_app/services/database_service.dart';
import 'package:dox_core/dox_core.dart';

void main() async {
  /// Initialize Dox
  Dox().initialize(appConfig);

  /// run database migration before starting server
  await DatabaseService().migrate();

  /// start dox http server
  await Dox().startServer();
}
