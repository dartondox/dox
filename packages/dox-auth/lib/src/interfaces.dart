import 'package:dox_auth/src/auth_engine.dart';
import 'package:dox_core/utils/hash.dart';
import 'package:dox_orm/dox_orm.dart';

class AuthGuard {
  final AuthDriver driver;
  final AuthProvider provider;

  const AuthGuard({required this.driver, required this.provider});
}

class AuthProvider {
  final dynamic Function() model;

  final List<String> identifierFields;
  final String passwordField;

  const AuthProvider({
    required this.model,
    this.identifierFields = const <String>['email'],
    this.passwordField = 'password',
  });
}

class AuthConfig {
  final String defaultGuard;
  final Map<String, AuthGuard> guards;

  AuthConfig({
    required this.defaultGuard,
    this.guards = const <String, AuthGuard>{},
  });
}

/// A driver checks tokens and logins for a guard.
/// [guard] is the name of the guard in `AuthConfig.guards`.
/// Use `AuthEngine().guard(guard).provider` to get its user provider.
abstract class AuthDriver {
  Future<Model<dynamic>?> verifyToken(IDoxRequest req, String guard);

  Future<Model<dynamic>?> attempt(
    Map<String, dynamic> credentials,
    String guard,
  );

  String? createToken(Map<String, dynamic>? userPayload, String guard);

  /// checked when no user is found, so a login takes as long for an
  /// unknown email as for a wrong password. One per bcrypt cost.
  static final Map<int, Future<String>> _dummyHashes = <int, Future<String>>{};

  /// Make the dummy hash of [rounds] now, in another isolate, so the
  /// first login does not pay for it. A bad cost fails on the first
  /// login, not here.
  static void prepareDummyHash(int rounds) {
    _dummyHashes.putIfAbsent(rounds, () {
      return Hash.makeAsync('dox-no-user', rounds: rounds)..ignore();
    });
  }

  /// The user of [credentials] when the password matches, else null.
  /// [rounds] is the bcrypt cost of the stored hashes.
  static Future<Model<dynamic>?> checkCredentials(
    Map<String, dynamic> credentials,
    String guard,
    int rounds,
  ) async {
    AuthProvider provider = AuthEngine().guard(guard).provider;

    /// password must be a string, otherwise login fails
    dynamic password = credentials[provider.passwordField];
    if (password is! String) {
      return null;
    }

    /// setup new model from auth config
    Model<dynamic> model = provider.model();

    /// setup model query
    Model<dynamic> query = model.debug(model.shouldDebug);

    /// find with credential except password field
    /// since password field is encrypted, we do not need to include
    bool hasIdentifier = false;
    credentials.forEach((String key, dynamic value) {
      if (key != provider.passwordField &&
          provider.identifierFields.contains(key) &&
          value != null) {
        query.where(key, value);
        hasIdentifier = true;
      }
    });

    /// without an identifier the query would match any user
    if (!hasIdentifier) {
      return null;
    }

    /// get first record
    Model<dynamic>? userData = await query.getFirst();

    /// the stored hash. null when there is no user or no password.
    dynamic hashed = userData?.toMap(original: true)[provider.passwordField];
    bool hasHash = hashed is String;

    /// always run bcrypt, also when there is no user or no password,
    /// so the answer time does not tell whether the account exists
    /// bcrypt runs in another isolate, so other requests are not blocked
    prepareDummyHash(rounds);
    bool matches = await Hash.verifyAsync(
      password,
      hasHash ? hashed : await _dummyHashes[rounds]!,
    );
    if (userData != null && hasHash && matches) {
      return userData;
    }
    return null;
  }
}
