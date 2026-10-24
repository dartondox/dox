// ignore_for_file: depend_on_referenced_packages
import 'package:dox_auth/dox_auth.dart';
import 'package:dox_auth/src/hash.dart';
import 'package:dox_orm/dox_orm.dart';

class JwtAuthDriver extends AuthDriver {
  /// Jwt secret
  final JWTKey secret;

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

    /// made now in another isolate, so the first login does not
    /// pay for it. A bad cost fails on the first login, not here.
    _dummyHashes.putIfAbsent(hashRounds, () {
      return Hash.makeAsync('dox-no-user', rounds: hashRounds)..ignore();
    });
  }

  /// checked when no user is found, so a login takes as long for an
  /// unknown email as for a wrong password. One per bcrypt cost.
  static final Map<int, Future<String>> _dummyHashes = <int, Future<String>>{};

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

      /// verify token
      /// the audience is the guard name, so a token of one guard
      /// does not work for another guard.
      JWT jwt = JWT.verify(
        token,
        secret,
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
    bool matches = await Hash.verifyAsync(
      password,
      hasHash ? hashed : await _dummyHashes[hashRounds]!,
    );
    if (userData != null && hasHash && matches) {
      return userData;
    }
    return null;
  }

  /// set login and get jwt token
  /// ```
  /// String token = auth.login(user);
  /// ```
  @override
  String? createToken(Map<String, dynamic>? userPayload, String guard) {
    try {
      JWT jwt = JWT(userPayload, issuer: issuer, audience: Audience.one(guard));
      return jwt.sign(secret, algorithm: algorithm, expiresIn: expiresIn);
    } catch (error) {
      return null;
    }
  }
}
