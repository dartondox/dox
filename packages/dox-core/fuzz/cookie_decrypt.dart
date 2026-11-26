import 'package:dox_core/dox_core.dart';

import 'src/fuzz_target.dart';

/// The value of an encrypted cookie, read like `req.cookie(name)`.
/// A changed value must not decrypt to a new text.
class CookieDecryptTarget extends FuzzTarget {
  CookieDecryptTarget();

  static const String secret = 'fuzz-secret-0123456789-0123456789';
  static const String cookie = 'dox_session';
  static const List<String> texts = <String>['', 'hello', '{"user":5}'];

  /// each run makes new seeds: the nonce of a value is random
  @override
  final List<String> seeds = <String>[
    for (String text in texts)
      AESEncryptor.encode(
        text,
        secret,
        associatedData: cookie,
        purpose: KeyDerivation.cookie,
      ),
  ];

  @override
  String get name => 'cookie_decrypt';

  @override
  String get library => 'package:dox_core/utils/aes_encryptor.dart';

  @override
  void check(String input) {
    String text = AESEncryptor.decode(
      input,
      secret,
      associatedData: cookie,
      purpose: KeyDerivation.cookie,
    );
    if (!texts.contains(text)) throw StateError('forged text "$text"');
  }
}

Future<void> main(List<String> args) => CookieDecryptTarget().run(args);
