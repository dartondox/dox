// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';

import 'package:dox_auth/dox_auth.dart';
import 'package:dox_core/env/env.dart';
import 'package:dox_core/utils/key_derivation.dart';
import 'package:dox_orm/dox_orm.dart';

class JwtAuthDriver extends AuthDriver {
  /// Jwt secret.
  /// A [SecretKey] (like `SecretKey(env.appKey)`) is not used as it is.
  /// The HMAC key is made from it with HKDF-SHA256 and the label
  /// `dox:jwt` (see `KeyDerivation`), so APP_KEY is not shared with
  /// cookies or other uses. [signingKey] gives that key, for another
  /// service that checks the tokens. Other keys (RSA, EC) are used as
  /// they are.
  final JWTKey secret;

  /// The key that signs and checks the tokens. See [secret].
  late final JWTKey signingKey = _signingKey(secret);

  /// JWT issuer
  final String? issuer;

  /// JWT algorithm
  final JWTAlgorithm algorithm;

  /// How long a token is valid. Default: 1 hour.
  final Duration expiresIn;

  /// bcrypt cost of the stored password hashes. Default: 10.
  /// Set it to the cost you use with `Hash.make`, so a login for an
  /// unknown email takes as long as a wrong password.
  final int hashRounds;

  /// Keep the user of a token in memory for this long, so
  /// `verifyToken` does not load the user from the database on every
  /// request. Off (`null`) by default.
  /// A change to the user (eg. delete or ban) is seen only after this
  /// time. Each server isolate has its own cache. Requests in this
  /// time share the same user object, so do not change it per request.
  final Duration? userCacheTtl;

  /// most users kept by [userCacheTtl]. When full, the cache is cleared.
  static const int _userCacheSize = 1000;

  final Map<String, (Model<dynamic>, DateTime)> _userCache =
      <String, (Model<dynamic>, DateTime)>{};

  /// constructor
  JwtAuthDriver({
    required this.secret,
    this.algorithm = JWTAlgorithm.HS256,
    this.expiresIn = const Duration(hours: 1),
    this.issuer,
    this.hashRounds = 10,
    this.userCacheTtl,
  }) {
    /// with an empty key anyone can sign a token for any user
    JWTKey key = secret;
    if (key is SecretKey && key.key.trim().isEmpty) {
      throw ArgumentError(
        'The JWT secret is empty. Set APP_KEY (run `dox key:generate`).',
        'secret',
      );
    }
    if (key is SecretKey) _checkSecretLength(key.key);

    AuthDriver.prepareDummyHash(hashRounds);
  }

  static JWTKey _signingKey(JWTKey secret) {
    if (secret is! SecretKey) return secret;
    return SecretKey(
      base64.encode(KeyDerivation.derive(secret.key, KeyDerivation.jwt)),
      isBase64Encoded: true,
    );
  }

  /// fewest bytes of an HMAC secret. A shorter one is easy to guess.
  static const int minSecretBytes = 32;

  /// A short secret stops the app in production, and only warns in
  /// development, local, test and testing (like the APP_KEY check of
  /// dox_core).
  static void _checkSecretLength(String secret) {
    int length = utf8.encode(secret).length;
    if (length >= minSecretBytes) return;
    String message =
        'The JWT secret is $length bytes. It must be at least '
        '$minSecretBytes bytes. Run `dox key:generate` for APP_KEY, '
        'or make a secret with `openssl rand -hex 32`.';
    String env = Env.get<String>('APP_ENV').toLowerCase();
    if (!<String>['development', 'local', 'test', 'testing'].contains(env)) {
      throw ArgumentError(message, 'secret');
    }
    print('[dox] warning: $message');
  }

  /// verify token and get model from provider
  /// and get user data
  @override
  Future<Model<dynamic>?> verifyToken(IDoxRequest req, String guard) async {
    try {
      AuthProvider provider = AuthEngine().guard(guard).provider;

      /// get token from header
      String? token = req.header('Authorization')?.replaceFirst('Bearer ', '');

      /// if not token just return
      if (token == null) {
        return null;
      }

      /// only the configured algorithm is accepted, so a token can not
      /// pick another one (like `none`, or HS256 with a public RSA key).
      if (JWT.decode(token).header?['alg'] != algorithm.name) {
        return null;
      }

      /// verify token
      /// the audience is the guard name, so a token of one guard
      /// does not work for another guard.
      JWT jwt = JWT.verify(
        token,
        signingKey,
        audience: Audience.one(guard),
        issuer: issuer,
      );

      /// get the payload
      Map<String, dynamic> payload = jwt.payload;

      /// get model from provider
      Model<dynamic> model = provider.model();

      /// get id from payload
      dynamic id = payload[model.primaryKey];

      if (id == null) {
        return null;
      }

      Duration? ttl = userCacheTtl;
      if (ttl == null) {
        /// by user by id
        return await model.find(id);
      }

      String cacheKey = '$guard:$id';
      DateTime now = DateTime.now();
      (Model<dynamic>, DateTime)? cached = _userCache[cacheKey];
      if (cached != null && now.isBefore(cached.$2)) {
        return cached.$1;
      }
      Model<dynamic>? user = await model.find(id);
      if (user == null) {
        _userCache.remove(cacheKey);
        return null;
      }
      if (_userCache.length >= _userCacheSize) {
        _userCache.clear();
      }
      _userCache[cacheKey] = (user, now.add(ttl));
      return user;
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
  Future<Model<dynamic>?> attempt(
    Map<String, dynamic> credentials,
    String guard,
  ) {
    return AuthDriver.checkCredentials(credentials, guard, hashRounds);
  }

  /// set login and get jwt token
  /// ```
  /// String token = auth.login(user);
  /// ```
  @override
  String? createToken(Map<String, dynamic>? userPayload, String guard) {
    try {
      JWT jwt = JWT(userPayload, issuer: issuer, audience: Audience.one(guard));
      return jwt.sign(signingKey, algorithm: algorithm, expiresIn: expiresIn);
    } catch (error) {
      return null;
    }
  }
}
