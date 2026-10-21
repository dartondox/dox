import 'package:dox_core/env/env.dart';
import 'package:dox_openapi/dox_openapi.dart';

/// OpenAPI docs for the app: `/docs`, `/openapi.json` and `/openapi.yaml`.
///
/// ```
/// import 'package:my_app/openapi.g.dart';
///
/// OpenApiConfig(
///   info: Info(title: 'Blog API', version: '1.0.0'),
///   registry: openApiRegistry,
/// );
/// ```
class OpenApiConfig {
  /// Serve the docs routes. When null, they are on only when `APP_ENV`
  /// is `development` or `local`, so production is off by default.
  final bool? enabled;

  /// Title and version of the API.
  final Info info;

  /// Base URLs of the API.
  final List<Server> servers;

  /// Ways to log in, like `{'bearerAuth': SecurityScheme.bearer()}`.
  final Map<String, SecurityScheme> securitySchemes;

  /// Security for routes that use a middleware class with this name.
  /// `AuthMiddleware` gets `bearerAuth` when it is not in this map.
  final Map<String, List<Map<String, List<String>>>> securityByMiddleware;

  /// What `dox_builder` found in the code: controller docs, route calls
  /// and model schemas. Pass `openApiRegistry` from the generated
  /// `lib/openapi.g.dart`. Run `dart run build_runner build` to make it.
  final OpenApiRegistry registry;

  const OpenApiConfig({
    this.enabled,
    this.info = const Info(title: 'Dox API', version: '1.0.0'),
    this.servers = const <Server>[],
    this.securitySchemes = const <String, SecurityScheme>{},
    this.securityByMiddleware =
        const <String, List<Map<String, List<String>>>>{},
    this.registry = const OpenApiRegistry(),
  });

  /// true when the docs routes are served
  bool get isEnabled {
    bool? value = enabled;
    if (value != null) return value;
    String env = Env.get<String>('APP_ENV').toLowerCase();
    return env == 'development' || env == 'local';
  }
}
