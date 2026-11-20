import 'package:dox_core/dox_core.dart';

/// A middleware that logs a user in.
///
/// A package that serves many routes behind one endpoint (like GraphQL)
/// uses it to find the user without blocking guests.
abstract class IAuthMiddleware implements IDoxMiddleware {
  /// Gives the same middleware (with the same guards) that lets guests
  /// through. A good login sets `req.auth`. No login, or a bad token,
  /// goes on with `req.auth` null.
  IAuthMiddleware asOptional();
}
