/// Opt-in behaviors that work like Laravel. Every flag is off by default.
/// Pass it as `AppConfig(flags: ...)`.
/// ```
/// AppConfig(appKey: key, flags: const CoreFlags(onlyPresent: true));
/// AppConfig(appKey: key, flags: const CoreFlags.all());
/// ```
/// Each isolate builds its own `AppConfig`, so each one reads the same
/// flags. Dox reads them when the code runs, from `Dox().flags`.
class CoreFlags {
  const CoreFlags({
    this.laravelErrors = false,
    this.onlyPresent = false,
    this.cookieDefaults = false,
    this.hasKeyOnly = false,
    this.htmlStrings = false,
    this.replaceHeaders = false,
    this.keepCsrfToken = false,
    this.decryptServerError = false,
    this.cacheCopies = false,
  });

  /// Every flag on.
  const CoreFlags.all()
    : laravelErrors = true,
      onlyPresent = true,
      cookieDefaults = true,
      hasKeyOnly = true,
      htmlStrings = true,
      replaceHeaders = true,
      keepCsrfToken = true,
      decryptServerError = true,
      cacheCopies = true;

  /// A 422 answer is `{"message": "...", "errors": {"field": ["..."]}}`,
  /// with all messages of each field. Off: `{"field": "first message"}`.
  final bool laravelErrors;

  /// `req.only([...])` leaves out keys that are not in the input.
  /// Off: a missing key is in the map with `null`.
  final bool onlyPresent;

  /// A `DoxCookie` with no `path` gets `Path=/`, and one with no
  /// `sameSite` gets `SameSite=Lax`. Off: no `Path` and no `SameSite`.
  final bool cookieDefaults;

  /// `req.has('x')` is true when the key is in the input, with any value
  /// (also `''` or null), like `req.exists('x')`. Off: `''` and null give
  /// false.
  final bool hasKeyOnly;

  /// A string from a controller is sent as `text/html`. A content type
  /// set by the app wins. Off: `text/plain`.
  final bool htmlStrings;

  /// `res.header(k, v)` replaces a value of the header that is already on
  /// the response (for example one set by a middleware). Off: it adds a
  /// second value. `res.header(k, v, replace: ...)` wins over this flag.
  final bool replaceHeaders;

  /// `session.regenerate()` keeps the CSRF token, so forms open in other
  /// tabs still work after login. `session.invalidate()` still makes a
  /// new token. `regenerate(keepToken: ...)` wins over this flag.
  final bool keepCsrfToken;

  /// A `DecryptException` gives 500 and is reported by the
  /// `ExceptionHandler`. Off: it gives 400 and is not reported.
  final bool decryptServerError;

  /// `Cache().store('x')`, `.tag()` and `.tags()` give a new `Cache`, and
  /// the first one does not change. Off: they change the same object.
  final bool cacheCopies;
}
