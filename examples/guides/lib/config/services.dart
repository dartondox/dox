import 'package:dox_core/dox_core.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/cleanup_service.dart';
import 'package:my_app/services/orm_service.dart';

List<DoxService> services = <DoxService>[
  ORMService(),
  AuthService(),
  CleanupService(),
];
