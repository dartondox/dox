// ignore_for_file: depend_on_referenced_packages
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_auth/src/hash.dart';
import 'package:dox_query_builder/dox_query_builder.dart';

class JwtAuthDriver extends AuthDriver {
  /// Jwt secret
  final JWTKey secret;

  /// JWT issuer
  final String? issuer;

  /// JWT algorithm
  final JWTAlgorithm algorithm;

  /// JWT token expire duration
  final Duration? expiresIn;

  /// get auth driver
  AuthDriver get driver => AuthEngine().driver;

  /// get auth provider
  AuthProvider get provider => AuthEngine().provider;

  /// constructor
  JwtAuthDriver({
    required this.secret,
    this.algorithm = JWTAlgorithm.HS256,
    this.expiresIn,
    this.issuer,
  });

  /// verify token and get model from provider
  /// and get user data
  @override
  Future<Model<dynamic>?> verifyToken(IDoxRequest req) async {
    try {
      /// get token from header
      String? token = req.header('Authorization')?.replaceFirst('Bearer ', '');

      /// if not token just return
      if (token == null) {
        return null;
      }

      /// verify token
      JWT jwt = JWT.verify(token, secret);

      /// get the payload
      Map<String, dynamic> payload = jwt.payload;

      /// get model from provider
      Model<dynamic> model = provider.model();

      /// get id from payload
      dynamic id = payload[model.primaryKey];

      if (id != null) {
        /// by user by id
        return await model.find(id);
      }
    } catch (ex) {
      /// ignore any errors
    }
    return null;
  }

  /// attempt to login
  ///```
  /// String token = await auth.attempt(credentials);
  /// if(token == null) {
  ///   // failed to login
  /// }
  ///```
  @override
  Future<Model<dynamic>?> attempt(Map<String, dynamic> credentials) async {
    /// setup new model from auth config
    Model<dynamic> model = provider.model();

    /// setup model query
    Model<dynamic> query = model.debug(model.shouldDebug);

    /// find with credential except password field
    /// since password field is encrypted, we do not need to include
    credentials.forEach((String key, dynamic value) {
      if (key != provider.passwordField &&
          provider.identifierFields.contains(key)) {
        query.where(key, value);
      }
    });

    /// get first record
    Model<dynamic>? userData = await query.getFirst();

    if (userData != null) {
      /// convert to json to get password field
      Map<String, dynamic>? jsond = userData.toMap(original: true);

      /// verify password
      bool passwordVerified = Hash.verify(
        credentials[provider.passwordField],
        jsond[provider.passwordField]!,
      );

      if (passwordVerified) {
        /// if password is verify login and get jwt token
        return userData;
      }
    }
    return null;
  }

  /// set login and get jwt token
  /// ```
  /// String token = auth.login(user);
  /// ```
  @override
  String? createToken(Map<String, dynamic>? userPayload) {
    try {
      JWT jwt = JWT(userPayload, issuer: issuer);
      return jwt.sign(
        secret,
        algorithm: algorithm,
        expiresIn: expiresIn,
      );
    } catch (error) {
      return null;
    }
  }
}
