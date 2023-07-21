/// coverage:ignore-file
import 'package:dox_core/dox_core.dart';

abstract class AuthConfigInterface {
  String get defaultGuard => 'web';

  Map<String, dynamic> get guards => <String, Guard>{};
}

class Guard {
  final Driver driver;
  final Provider provider;

  const Guard({
    required this.driver,
    required this.provider,
  });
}

class Provider {
  final dynamic Function() model;

  final List<String> identifierFields;
  final String passwordField;

  const Provider({
    required this.model,
    this.identifierFields = const <String>['email'],
    this.passwordField = 'password',
  });
}

abstract class Driver {
  Future<void> verifyToken(DoxRequest req);

  bool isLoggedIn();

  T? user<T>();

  Future<String?> attempt(Map<String, dynamic> credentials);

  String login(Map<String, dynamic> user);

  Map<String, dynamic>? toJson();
}
