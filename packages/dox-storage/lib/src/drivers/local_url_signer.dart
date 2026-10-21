import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../clock.dart';
import '../constants/storage_constants.dart';
import '../exceptions.dart';
import '../key_normalizer.dart';

/// Signs and checks local file URLs with HMAC-SHA256 and an app key.
///
/// A signed URL looks like `<base>/<key>?expires=<ms>&signature=<hex>`.
/// Your route checks it with [verify] before it serves the file.
class LocalUrlSigner {
  final List<int> _secret;
  final Clock clock;
  final KeyNormalizer normalizer;
  final KeyEncoder encoder;

  LocalUrlSigner(
    String appKey, {
    this.clock = const Clock(),
    this.normalizer = const KeyNormalizer(),
    this.encoder = const KeyEncoder(),
  }) : _secret = utf8.encode(appKey) {
    if (appKey.isEmpty) {
      throw ArgumentError.value(appKey, 'appKey', 'must not be empty');
    }
  }

  /// Build a signed URL for [key] under [urlBase].
  String sign(String urlBase, String key, Duration expiresIn) {
    String cleanKey = normalizer.key(key);
    int expires = clock.now().add(expiresIn).millisecondsSinceEpoch;
    String signature = _signature(cleanKey, expires);
    String base = urlBase.endsWith('/')
        ? urlBase.substring(0, urlBase.length - 1)
        : urlBase;
    return '$base/${encoder.urlPath(cleanKey)}'
        '?${StorageConstants.localExpiresParam}=$expires'
        '&${StorageConstants.localSignatureParam}=$signature';
  }

  /// True when [queryParameters] hold a valid, not expired signature
  /// for [key]. Pass the decoded key from the route path.
  bool verify(String key, Map<String, String> queryParameters) {
    String cleanKey;
    try {
      cleanKey = normalizer.key(key);
    } on InvalidKeyException {
      return false;
    }
    int? expires = int.tryParse(
      queryParameters[StorageConstants.localExpiresParam] ?? '',
    );
    String? signature = queryParameters[StorageConstants.localSignatureParam];
    if (expires == null || signature == null) {
      return false;
    }
    if (clock.now().millisecondsSinceEpoch > expires) {
      return false;
    }
    return _constantTimeEquals(_signature(cleanKey, expires), signature);
  }

  String _signature(String key, int expires) {
    Hmac hmac = Hmac(sha256, _secret);
    return hmac.convert(utf8.encode('$key\n$expires')).toString();
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
