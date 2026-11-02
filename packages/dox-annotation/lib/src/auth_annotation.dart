import 'package:dox_annotation/dox_annotation.dart';

abstract class IAuth {
  Future<void> verifyToken(IDoxRequest req);
  bool isLoggedIn();
  T? user<T>();
  Map<String, dynamic>? toJson();
}

/// A helper on `req.auth`, which is typed `IAuth?`.
/// It is an extension, not a member of [IAuth], so a class that
/// `implements IAuth` does not have to add it.
/// For a guest, `req.auth` is null, so check `req.auth == null`.
/// ```
/// if (post.userId != req.auth?.id()) abort(403);
/// ```
extension IAuthHelpers on IAuth {
  /// The primary key of the logged-in user, or null for a guest.
  /// It calls the `id()` of the auth class (like `Auth` of `dox_auth`).
  /// An auth class with no `id()` gives null.
  /// A `NoSuchMethodError` thrown inside a real `id()` is also caught and
  /// gives null.
  dynamic id() {
    try {
      // ponytail: dynamic call reaches the class's own id(); an extension
      // cannot be overridden, so this is how `Auth.id()` is used.
      return (this as dynamic).id();
    } on NoSuchMethodError {
      return null;
    }
  }
}
