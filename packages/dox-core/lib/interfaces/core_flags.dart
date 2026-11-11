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
      decryptServerError = true,
      cacheCopies = true;

  /// A 422 answer is `{"message": "...", "errors": {"field": ["..."]}}`,
  /// with all messages of each field. Off: `{"field": "first message"}`.
  // NEXT MAJOR: make this the default, then remove the flag.
  final bool laravelErrors;

  /// `req.only([...])` leaves out keys that are not in the input.
  /// Off: a missing key is in the map with `null`.
  // NEXT MAJOR: make this the default, then remove the flag.
  final bool onlyPresent;

  /// A `DoxCookie` with no `path` gets `Path=/`, and one with no
  /// `sameSite` gets `SameSite=Lax`. Off: no `Path` and no `SameSite`.
  // NEXT MAJOR: make this the default, then remove the flag.
  final bool cookieDefaults;

  /// `req.has('x')` is true when the key is in the input, with any value
  /// (also `''` or null), like `req.exists('x')`. Off: `''` and null give
  /// false.
  // NEXT MAJOR: make this the default, then remove the flag.
  final bool hasKeyOnly;

  /// A string from a controller is sent as `text/html`. A content type
  /// set by the app wins. Off: `text/plain`.
  // NEXT MAJOR: make this the default, then remove the flag.
  final bool htmlStrings;

  /// `res.header(k, v)` replaces a value of the header that is already on
  /// the response (for example one set by a middleware). Off: it adds a
  /// second value. `res.header(k, v, replace: ...)` wins over this flag.
  // NEXT MAJOR: make this the default, then remove the flag.
  final bool replaceHeaders;

  /// A `DecryptException` gives 500 and is reported by the
  /// `ExceptionHandler`. Off: it gives 400 and is not reported.
  // NEXT MAJOR: make this the default, then remove the flag.
  final bool decryptServerError;

  /// `Cache().store('x')`, `.tag()` and `.tags()` give a new `Cache`, and
  /// the first one does not change. Off: they change the same object.
  // NEXT MAJOR: make this the default, then remove the flag.
  final bool cacheCopies;
}
