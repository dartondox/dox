import 'package:dox_core/dox_core.dart';
import 'package:my_app/config/env.dart';

/// `enabled` is true by default, so every route sends the headers.
CORSConfig cors = CORSConfig(
  /// One origin only. A list is joined with commas, and browsers reject
  /// that value. Set CORS_ORIGIN to the real front-end URL in production.
  origin: env.corsOrigin,

  methods: <String>['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],

  /// the request headers the front-end sends
  headers: <String>['Content-Type', 'Authorization'],

  /// the response headers the front-end may read
  exposeHeaders: <String>['Content-Disposition'],

  /// true only when the front-end sends cookies. Not needed for a
  /// `Authorization: Bearer` token.
  credentials: false,

  /// the browser keeps the preflight answer for 10 minutes
  maxAge: 600,
);
