/// Global constants for dox_openapi.
class OpenApiConstants {
  /// The OpenAPI version this package writes.
  static const String openApiVersion = '3.1.0';

  /// Prefix for a reference to a named schema.
  static const String schemaRefPrefix = '#/components/schemas/';

  /// File name for the JSON output.
  static const String jsonFileName = 'openapi.json';

  /// File name for the YAML output.
  static const String yamlFileName = 'openapi.yaml';

  /// URL path for the JSON document.
  static const String jsonPath = '/openapi.json';

  /// URL path for the YAML document.
  static const String yamlPath = '/openapi.yaml';

  /// URL path for the HTML docs page.
  static const String docsPath = '/docs';

  /// Content type for JSON.
  static const String jsonContentType = 'application/json; charset=utf-8';

  /// Content type for YAML.
  static const String yamlContentType = 'application/yaml; charset=utf-8';

  /// Content type for HTML.
  static const String htmlContentType = 'text/html; charset=utf-8';

  /// Media type used for request and response bodies.
  static const String bodyMediaType = 'application/json';

  /// Swagger UI version loaded from the CDN.
  static const String swaggerUiVersion = '5.34.0';

  /// Scalar (`@scalar/api-reference`) version loaded from the CDN.
  static const String scalarVersion = '1.75.1';

  /// HTTP methods that OpenAPI 3.1 allows in a path item.
  static const List<String> methods = <String>[
    'get',
    'put',
    'post',
    'delete',
    'options',
    'head',
    'patch',
    'trace',
  ];

  /// Response description for routes that have no docs.
  static const String defaultResponseDescription = 'Successful response';
}
