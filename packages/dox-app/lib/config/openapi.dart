import 'package:dox_core/dox_core.dart';

/// OpenAPI docs
/// -------------------------------
/// `/docs`, `/openapi.json` and `/openapi.yaml`.
/// On when APP_ENV is development or local. Off in production.
/// `dox openapi:generate` writes the files to storage/openapi.
OpenApiConfig openApi = OpenApiConfig(
  info: Info(title: Env.get('APP_NAME', 'dox'), version: '1.0.0'),
  securitySchemes: <String, SecurityScheme>{
    'bearerAuth': SecurityScheme.bearer(),
  },
  securityByMiddleware: <String, List<Map<String, List<String>>>>{
    'AuthMiddleware': <Map<String, List<String>>>[
      <String, List<String>>{'bearerAuth': <String>[]},
    ],
  },
);
