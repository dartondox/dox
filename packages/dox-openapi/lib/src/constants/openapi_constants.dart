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

  /// Media type used for request bodies that have a file field.
  static const String multipartMediaType = 'multipart/form-data';

  /// Swagger UI version loaded from the CDN.
  static const String swaggerUiVersion = '5.34.0';

  /// SRI hash of `swagger-ui.css`. The browser refuses a file whose hash
  /// does not match. Change it together with [swaggerUiVersion].
  static const String swaggerUiCssHash =
      'sha384-4c3vsE5f+trhFyHrFrLM1fFGUn531NIaC7dcqEWIJdoRQJ5CkJbSuSCwXLpaS1KF';

  /// SRI hash of `swagger-ui-bundle.js`. Change it with [swaggerUiVersion].
  static const String swaggerUiJsHash =
      'sha384-9Td7MKiIr2S83E1kZyyVi8KdJw/S8CpAvu0llLyMeg0xq/hDGiZJfVn0fV4llCmK';

  /// Scalar (`@scalar/api-reference`) version loaded from the CDN.
  static const String scalarVersion = '1.75.1';

  /// SRI hash of the Scalar script. Change it together with [scalarVersion].
  static const String scalarHash =
      'sha384-G+2Q2i9l3PPfmYkk0b4BAIUrs7xb/DNaTL1wCYYab4c9dIKlCyiqzC0Qx3eq9Wf6';

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
