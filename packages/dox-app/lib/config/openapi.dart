import 'package:dox_app/openapi.g.dart';
import 'package:dox_app/config/env.dart';
import 'package:dox_core/dox_core.dart';

/// OpenAPI docs
/// -------------------------------
/// `/docs`, `/openapi.json` and `/openapi.yaml`.
/// On when APP_ENV is development or local. Off in production.
/// `dox openapi:generate` writes the files to storage/openapi.
///
/// The docs come from the routes, the controllers and the models.
/// `dart run build_runner build` makes `lib/openapi.g.dart`.
///
/// `/docs` uses Scalar. Use `ui: DocsUi.swagger` for Swagger UI, and
/// `scalar: ScalarOptions(...)` for the theme and dark mode.
OpenApiConfig openApi = OpenApiConfig(
  info: Info(title: env.appName, version: '1.0.0'),
  registry: openApiRegistry,
);
