/// Opt-in behaviors that change the defaults. Every flag is off by default.
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
    this.envExpand = false,
    this.rateLimitIpv6Prefix = false,
    this.isolateGroups = false,
  });

  /// Every flag on, but not `isolateGroups`: that one changes how the
  /// app starts, so turn it on by name.
  const CoreFlags.all()
    : laravelErrors = true,
      onlyPresent = true,
      cookieDefaults = true,
      hasKeyOnly = true,
      htmlStrings = true,
      replaceHeaders = true,
      decryptServerError = true,
      cacheCopies = true,
      envExpand = true,
      rateLimitIpv6Prefix = true,
      // not a default of the next major, and it runs `main()` in each
      // isolate: an app turns it on by name.
      isolateGroups = false;

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

  /// `.env` values can use `${OTHER}` (unquoted or in `"..."`), and a
  /// `"..."` value reads `\n`, `\t`, `\"`, `\\` and `\$`. Off: values are
  /// read as they are written.
  ///
  /// The `.env` file is read before `AppConfig` is made (the config reads
  /// env values). So also set `Env.flags` at the top of `main()`, before
  /// any env value is read:
  /// ```
  /// const CoreFlags flags = CoreFlags(envExpand: true);
  /// void main() {
  ///   Env.flags = flags;
  ///   Dox().initialize(AppConfig(..., flags: flags));
  /// }
  /// ```
  // NEXT MAJOR: make this the default, then remove the flag.
  final bool envExpand;

  /// The default key of `RateLimit` counts an IPv6 client by its /64
  /// prefix, and an IPv4-mapped address (`::ffff:1.2.3.4`) as its IPv4
  /// address. A client with a /64 has 2^64 addresses, so with one count
  /// per address it gets a fresh count with each new address. Clients in
  /// the same /64 now share one count. A `key` from the app is used as
  /// it is. Off: each full ip has its own count.
  // NEXT MAJOR: make this the default, then remove the flag.
  final bool rateLimitIpv6Prefix;

  /// Each server isolate runs in its own isolate group, so it has its own
  /// heap and its own garbage collector. A pause of the GC in one isolate
  /// does not stop the others. Off: all isolates share one group.
  ///
  /// Each isolate starts the app again from `main()`, so `main()` must be
  /// safe to run more than once, and code after `startServer()` runs in
  /// each isolate (use `Dox().isPrimary` to run it once). The command line
  /// arguments are not passed on, so read settings from the environment.
  /// The config,
  /// providers and routes are built by `main()` in each isolate.
  ///
  /// It needs a file that the VM can start again: a `dart build cli`
  /// bundle on Linux, a file made with `dart compile aot-snapshot` (put
  /// it at `<executable>.aot`), or the script of `dart run`. When there
  /// is none, Dox logs one warning and runs as if the flag is off.
  ///
  /// `Dox().compute` has one pool per isolate. `Dox().isolateId` is
  /// right from the start of `main()`. `CoreFlags.all()` does not turn
  /// this flag on.
  // ponytail: a plain opt-in. Make it the default when it is proven in
  // production.
  final bool isolateGroups;
}
