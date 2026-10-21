import 'dart:convert';

/// The UI that shows the docs page at `/docs`.
enum DocsUi {
  /// Scalar API reference. The default.
  scalar,

  /// Swagger UI.
  swagger,
}

/// Color themes of Scalar. The names are the same as in Scalar.
enum ScalarTheme {
  /// Scalar's own theme.
  default_('default'),

  /// Scalar theme `alternate`.
  alternate('alternate'),

  /// Scalar theme `moon`.
  moon('moon'),

  /// Scalar theme `purple`.
  purple('purple'),

  /// Scalar theme `solarized`.
  solarized('solarized'),

  /// Scalar theme `bluePlanet`.
  bluePlanet('bluePlanet'),

  /// Scalar theme `deepSpace`.
  deepSpace('deepSpace'),

  /// Scalar theme `saturn`.
  saturn('saturn'),

  /// Scalar theme `kepler`.
  kepler('kepler'),

  /// Scalar theme `elysiajs`.
  elysiajs('elysiajs'),

  /// Scalar theme `fastify`.
  fastify('fastify'),

  /// Scalar theme `mars`.
  mars('mars'),

  /// Scalar theme `laserwave`.
  laserwave('laserwave'),

  /// No theme. Use your own CSS.
  none('none');

  /// The name Scalar uses.
  final String value;

  const ScalarTheme(this.value);
}

/// Options for the Scalar docs page.
///
/// ```
/// ScalarOptions(theme: ScalarTheme.purple, darkMode: true)
/// ```
class ScalarOptions {
  /// Color theme.
  final ScalarTheme theme;

  /// Start in dark mode. The user can still switch.
  final bool darkMode;

  /// Show the button that downloads the OpenAPI document.
  final bool showDownloadButton;

  /// Send "Try it" requests through this proxy, like
  /// `https://proxy.scalar.com`. Off when null, so requests go straight
  /// from the browser to the API.
  final String? proxyUrl;

  /// Creates Scalar options.
  const ScalarOptions({
    this.theme = ScalarTheme.default_,
    this.darkMode = false,
    this.showDownloadButton = true,
    this.proxyUrl,
  });

  /// The config object for `Scalar.createApiReference()`.
  Map<String, dynamic> toJson(String specUrl) {
    return <String, dynamic>{
      'url': specUrl,
      'theme': theme.value,
      'darkMode': darkMode,
      'documentDownloadType': showDownloadButton ? 'both' : 'none',
      'proxyUrl': ?proxyUrl,
    };
  }
}

/// JSON that is safe inside a `<script>` tag.
///
/// `<` only shows up inside JSON strings, so `\u003c` keeps the same
/// value and a `</script>` in a value can not close the tag.
String scriptJson(Object? value) {
  return jsonEncode(value).replaceAll('<', r'\u003c');
}
