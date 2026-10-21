import 'dart:convert';
import 'dart:io';

import 'constants/openapi_constants.dart';
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

  /// Creates a server helper.
  OpenApiServer(this.api, {String? pageTitle})
      : pageTitle = pageTitle ?? api.info.title;

  /// The JSON document.
  OpenApiResponse json() {
    return OpenApiResponse(
        api.toJsonString(), OpenApiConstants.jsonContentType);
  }

  /// The YAML document.
  OpenApiResponse yaml() {
    return OpenApiResponse(api.toYaml(), OpenApiConstants.yamlContentType);
  }

  /// A Swagger UI page that loads [specUrl] from a CDN.
  OpenApiResponse docsPage({String specUrl = OpenApiConstants.jsonPath}) {
    String cdn = 'https://cdn.jsdelivr.net/npm/swagger-ui-dist@'
        '${OpenApiConstants.swaggerUiVersion}';
    String title = const HtmlEscape().convert(pageTitle);
    String url = jsonEncode(specUrl);
    String html = '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$title</title>
  <link rel="stylesheet" href="$cdn/swagger-ui.css">
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="$cdn/swagger-ui-bundle.js"></script>
  <script>
    window.ui = SwaggerUIBundle({ url: $url, dom_id: '#swagger-ui' });
  </script>
</body>
</html>
''';
    return OpenApiResponse(html, OpenApiConstants.htmlContentType);
  }

  /// Returns the content for [path], or null when it is not a docs path.
  OpenApiResponse? handle(String path) {
    switch (path) {
      case OpenApiConstants.jsonPath:
        return json();
      case OpenApiConstants.yamlPath:
        return yaml();
      case OpenApiConstants.docsPath:
        return docsPage();
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
