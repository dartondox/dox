import 'dart:convert';
import 'dart:io';

import 'constants/openapi_constants.dart';
import 'docs_ui.dart';
import 'dox_route_adapter.dart';
import 'openapi.dart';

/// Body text and content type for one docs URL.
class OpenApiResponse {
  /// Response body.
  final String body;

  /// Value for the `Content-Type` header.
  final String contentType;

  /// Creates a response.
  const OpenApiResponse(this.body, this.contentType);
}

/// Gives the content for `/openapi.json`, `/openapi.yaml` and `/docs`.
///
/// It does not depend on any router. The app registers the three paths
/// and returns [OpenApiResponse.body] with [OpenApiResponse.contentType].
class OpenApiServer {
  /// The document builder.
  final OpenApi api;

  /// Title of the HTML docs page.
  final String pageTitle;

  /// The UI of the docs page. Scalar by default.
  final DocsUi ui;

  /// Options for the Scalar page.
  final ScalarOptions scalar;

  /// Creates a server helper.
  OpenApiServer(
    this.api, {
    String? pageTitle,
    this.ui = DocsUi.scalar,
    this.scalar = const ScalarOptions(),
  }) : pageTitle = pageTitle ?? api.info.title;

  /// The document is made once, on the first call, and kept.
  late final Map<String, dynamic> _doc = api.toJson();
  late final OpenApiResponse _json = OpenApiResponse(
    const JsonEncoder.withIndent('  ').convert(_doc),
    OpenApiConstants.jsonContentType,
  );
  late final OpenApiResponse _yaml = OpenApiResponse(
    api.yamlEmitter.emit(_doc),
    OpenApiConstants.yamlContentType,
  );
  late final OpenApiResponse _page = docsPage();

  /// The JSON document. Made once, then kept.
  OpenApiResponse json() {
    return _json;
  }

  /// The YAML document. Made once, then kept.
  OpenApiResponse yaml() {
    return _yaml;
  }

  /// The HTML docs page ([ui]) that loads [specUrl].
  OpenApiResponse docsPage({String specUrl = OpenApiConstants.jsonPath}) {
    String html = switch (ui) {
      DocsUi.scalar => _scalarPage(specUrl),
      DocsUi.swagger => _swaggerPage(specUrl),
    };
    return OpenApiResponse(html, OpenApiConstants.htmlContentType);
  }

  /// Scalar from the CDN.
  String _scalarPage(String specUrl) {
    String script =
        'https://cdn.jsdelivr.net/npm/@scalar/api-reference@'
        '${OpenApiConstants.scalarVersion}/dist/browser/standalone.js';
    String config = scriptJson(scalar.toJson(specUrl));
    return '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${_title()}</title>
</head>
<body>
  <div id="app"></div>
  <script src="$script" integrity="${OpenApiConstants.scalarHash}" crossorigin="anonymous"></script>
  <script>
    Scalar.createApiReference('#app', $config);
  </script>
</body>
</html>
''';
  }

  /// Swagger UI from the CDN.
  String _swaggerPage(String specUrl) {
    String cdn =
        'https://cdn.jsdelivr.net/npm/swagger-ui-dist@'
        '${OpenApiConstants.swaggerUiVersion}';
    String url = scriptJson(specUrl);
    return '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${_title()}</title>
  <link rel="stylesheet" href="$cdn/swagger-ui.css" integrity="${OpenApiConstants.swaggerUiCssHash}" crossorigin="anonymous">
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="$cdn/swagger-ui-bundle.js" integrity="${OpenApiConstants.swaggerUiJsHash}" crossorigin="anonymous"></script>
  <script>
    window.ui = SwaggerUIBundle({ url: $url, dom_id: '#swagger-ui' });
  </script>
</body>
</html>
''';
  }

  String _title() {
    return const HtmlEscape().convert(pageTitle);
  }

  /// Returns the content for [path], or null when it is not a docs path.
  OpenApiResponse? handle(String path) {
    switch (path) {
      case OpenApiConstants.jsonPath:
        return json();
      case OpenApiConstants.yamlPath:
        return yaml();
      case OpenApiConstants.docsPath:
        return _page;
    }
    return null;
  }

  /// The paths this helper answers.
  List<String> get paths {
    return const <String>[
      OpenApiConstants.jsonPath,
      OpenApiConstants.yamlPath,
      OpenApiConstants.docsPath,
    ];
  }
}

/// Entry point for the `dox openapi:generate` command.
///
/// Adds [routes] (for example dox_core `Route().routes`) that have no docs
/// yet, then writes `openapi.json` and `openapi.yaml` into [outputDir].
Future<List<File>> generateOpenApi(
  OpenApi api,
  String outputDir, {
  Iterable<Object?> routes = const <Object?>[],
  DoxRouteAdapter adapter = const DoxRouteAdapter(),
}) async {
  adapter.addTo(api.docs, routes);
  return api.writeFiles(outputDir);
}
