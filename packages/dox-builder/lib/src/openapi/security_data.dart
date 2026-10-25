import 'package:analyzer/dart/constant/value.dart';

/// A login scheme from `@Security(...)` on a middleware class.
class SecurityData {
  const SecurityData(this.name, this.scheme);

  /// Name under `components/securitySchemes`.
  final String name;

  /// The OpenAPI security scheme object.
  final Map<String, dynamic> scheme;

  /// Reads `@Security.bearer(...)` or `@Security.apiKey(...)` on the
  /// class [className].
  factory SecurityData.read(String className, DartObject annotation) {
    String? type = annotation.getField('type')?.toStringValue();
    String? format = annotation.getField('format')?.toStringValue();
    String? header = annotation.getField('header')?.toStringValue();
    String? name = annotation.getField('scheme')?.toStringValue();
    Map<String, dynamic> scheme = type == 'apiKey'
        ? <String, dynamic>{'type': 'apiKey', 'name': header, 'in': 'header'}
        : <String, dynamic>{
            'type': 'http',
            'scheme': 'bearer',
            'bearerFormat': ?format,
          };
    return SecurityData(name ?? defaultName(className), scheme);
  }

  /// `ApiKeyAuthMiddleware` gives `apiKeyAuth`.
  static String defaultName(String className) {
    String name =
        className.endsWith('Middleware') &&
            className.length > 'Middleware'.length
        ? className.substring(0, className.length - 'Middleware'.length)
        : className;
    return name[0].toLowerCase() + name.substring(1);
  }
}
