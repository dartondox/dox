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
///
/// With [header] on, a POST can also ask for the method with the
/// `X-HTTP-Method-Override` header, like a JS client that can not send
/// PUT. The header wins over `_method`. It is off by default.
/// ```
/// globalMiddleware: <dynamic>[const MethodOverride(header: true)],
/// ```
class MethodOverride implements IDoxMiddleware {
  const MethodOverride({this.header = false});

  /// also read the [headerName] header
  final bool header;

  /// the form field name
  static const String field = '_method';

  /// the header name, read only when [header] is on
  static const String headerName = 'X-HTTP-Method-Override';

  static const Set<String> _allowed = <String>{'PUT', 'PATCH', 'DELETE'};

  @override
  IDoxRequest handle(IDoxRequest req) => req;

  /// The method [body] asks for with `_method`, or null when it asks for
  /// none or for one that is not PUT, PATCH or DELETE.
  static String? from(Map<String, dynamic> body) {
    return _allowedMethod(body[field]);
  }

  /// The method the [headerName] header [value] asks for, like [from].
  /// Null when no [MethodOverride] in the global middleware has [header]
  /// on.
  static String? fromHeader(String? value) {
    return _header ? _allowedMethod(value) : null;
  }

  static String? _allowedMethod(Object? value) {
    if (value is! String) return null;
    String method = value.toUpperCase();
    return _allowed.contains(method) ? method : null;
  }

  static List<dynamic>? _checked;
  static bool _on = false;
  static bool _header = false;

  /// true when [global] has a [MethodOverride]. checked again only when
  /// the list changes.
  static bool enabledIn(List<dynamic> global) {
    if (!identical(global, _checked)) {
      _checked = global;
      _on = false;
      _header = false;
      for (Object? item in global) {
        if (item is MethodOverride) {
          _on = true;
          if (item.header) _header = true;
        }
      }
    }
    return _on;
  }
}
