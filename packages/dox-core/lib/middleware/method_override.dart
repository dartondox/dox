import 'package:dox_core/dox_core.dart';

/// Lets a plain HTML form reach a `Route.put`, `Route.patch` or
/// `Route.delete` route. A form can only send GET or POST, so it sends
/// POST with a `_method` field:
///
/// ```html
/// <form method="POST" action="/posts/5">
///   <input type="hidden" name="_method" value="DELETE">
/// </form>
/// ```
///
/// Add it to `globalMiddleware`. It is off when it is not there.
///
/// ```
/// AppConfig(
///   globalMiddleware: <dynamic>[const MethodOverride()],
/// );
/// ```
///
/// Only a POST request changes, and only to PUT, PATCH or DELETE (in any
/// case). Any other `_method` value is ignored. `req.method` gives the
/// new method. `CsrfMiddleware` still checks the request, because it was
/// sent as POST.
///
/// The route is found before middleware runs, so Dox reads the body of a
/// POST request first and looks at `_method` there. A POST to a path
/// with no route for any method gets 404 with no body read. The middleware
/// itself does nothing; it only turns this on. It works only in
/// `AppConfig.globalMiddleware`, not on a router or a route.
class MethodOverride implements IDoxMiddleware {
  const MethodOverride();

  /// the form field name
  static const String field = '_method';

  static const Set<String> _allowed = <String>{'PUT', 'PATCH', 'DELETE'};

  @override
  IDoxRequest handle(IDoxRequest req) => req;

  /// The method [body] asks for with `_method`, or null when it asks for
  /// none or for one that is not PUT, PATCH or DELETE.
  static String? from(Map<String, dynamic> body) {
    Object? value = body[field];
    if (value is! String) return null;
    String method = value.toUpperCase();
    return _allowed.contains(method) ? method : null;
  }

  static List<dynamic>? _checked;
  static bool _on = false;

  /// true when [global] has a [MethodOverride]. checked again only when
  /// the list changes.
  static bool enabledIn(List<dynamic> global) {
    if (!identical(global, _checked)) {
      _checked = global;
      _on = false;
      for (Object? item in global) {
        if (item is MethodOverride) _on = true;
      }
    }
    return _on;
  }
}
