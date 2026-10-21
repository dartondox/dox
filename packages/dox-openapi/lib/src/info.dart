/// The `info` block of the document.
class Info {
  /// API title.
  final String title;

  /// API version, for example `1.0.0`.
  final String version;

  /// Optional longer text.
  final String? description;

  /// Creates the info block.
  const Info({required this.title, required this.version, this.description});

  /// Returns the OpenAPI info object.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'version': version,
      if (description != null) 'description': description,
    };
  }
}

/// One server the API runs on.
class Server {
  /// Base URL, for example `https://api.example.com`.
  final String url;

  /// Optional text, for example `Production`.
  final String? description;

  /// Creates a server entry.
  const Server(this.url, {this.description});

  /// Returns the OpenAPI server object.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'url': url,
      if (description != null) 'description': description,
    };
  }
}

/// A way to log in, placed under `components/securitySchemes`.
class SecurityScheme {
  final Map<String, dynamic> _json;

  /// Creates a scheme from a raw OpenAPI security scheme map.
  const SecurityScheme.raw(Map<String, dynamic> json) : _json = json;

  /// Bearer token in the `Authorization` header, JWT by default.
  SecurityScheme.bearer({String bearerFormat = 'JWT'})
      : _json = <String, dynamic>{
          'type': 'http',
          'scheme': 'bearer',
          'bearerFormat': bearerFormat,
        };

  /// API key in a header, query or cookie.
  SecurityScheme.apiKey({required String name, String location = 'header'})
      : _json = <String, dynamic>{
          'type': 'apiKey',
          'name': name,
          'in': location,
        };

  /// Returns the OpenAPI security scheme object.
  Map<String, dynamic> toJson() {
    return _json;
  }
}
