import 'package:dox_core/env/env.dart';
import 'package:dox_core/utils/path_pattern.dart';
import 'package:dox_openapi/dox_openapi.dart';

/// OpenAPI docs for the app: `/docs`, `/openapi.json` and `/openapi.yaml`.
///
/// ```
/// import 'package:my_app/generated/openapi.g.dart';
///
/// OpenApiConfig(
///   info: Info(title: 'Blog API', version: '1.0.0'),
///   registry: openApiRegistry,
/// );
/// ```
///
/// The page at `/docs` uses Scalar. Use `ui: DocsUi.swagger` for
/// Swagger UI.
class OpenApiConfig {
  /// Serve the docs routes. When null, they are on only when `APP_ENV`
  /// is `development` or `local`. An empty `APP_ENV` counts as
  /// production, so the docs are off.
  final bool? enabled;

  /// Title and version of the API.
  final Info info;

  /// Base URLs of the API.
  final List<Server> servers;

  /// Ways to log in, like `{'bearerAuth': SecurityScheme.bearer()}`.
  final Map<String, SecurityScheme> securitySchemes;

  /// Security for routes that use a middleware class with this name.
  /// It wins over `@Security` on the class. A class name that ends with
  /// `AuthMiddleware` gets `bearerAuth` when it has neither.
  final Map<String, List<Map<String, List<String>>>> securityByMiddleware;

  /// What `dox_builder` found in the code: controller docs, route calls
  /// and model schemas. Pass `openApiRegistry` from the generated
  /// `lib/generated/openapi.g.dart`. Run `dart run build_runner build` to make it.
  final OpenApiRegistry registry;

  /// The UI of the `/docs` page. Scalar by default.
  final DocsUi ui;

  /// Options for the Scalar page: theme, dark mode, download button
  /// and proxy.
  final ScalarOptions scalar;

  /// Title of the `/docs` page. Uses [Info.title] when null.
  final String? pageTitle;

  /// Only routes with these paths are in the docs, like
  /// `<String>['/api/*']`. A `*` at the end matches the rest of the
  /// path. When empty, all routes are in the docs.
  final List<String> include;

  /// Routes with these paths are left out of the docs, like
  /// `<String>['/api/internal/*']`. Checked after [include].
  final List<String> exclude;

  const OpenApiConfig({
    this.enabled,
    this.info = const Info(title: 'Dox API', version: '1.0.0'),
    this.servers = const <Server>[],
    this.securitySchemes = const <String, SecurityScheme>{},
    this.securityByMiddleware =
        const <String, List<Map<String, List<String>>>>{},
    this.registry = const OpenApiRegistry(),
    this.ui = DocsUi.scalar,
    this.scalar = const ScalarOptions(),
    this.pageTitle,
    this.include = const <String>[],
    this.exclude = const <String>[],
  });

  /// true when the route at [path] goes in the docs
  bool documents(String path) {
    if (include.isNotEmpty && !PathPattern.any(include, path)) return false;
    return !PathPattern.any(exclude, path);
  }

  /// true when the docs routes are served
  bool get isEnabled {
    bool? value = enabled;
    if (value != null) return value;
    String env = Env.get<String>('APP_ENV').toLowerCase();
    return env == 'development' || env == 'local';
  }
}
