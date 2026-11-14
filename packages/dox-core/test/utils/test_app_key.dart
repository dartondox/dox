import 'dart:math';

/// A new random `APP_KEY` for each test run. A key written in a file in git
/// is public, and `Dox().checkAppKey()` refuses the known ones. So the
/// tests never use one.
final String testAppKey = _randomKey();

String _randomKey() {
  const String chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  Random random = Random.secure();
  StringBuffer key = StringBuffer();
  for (int i = 0; i < 32; i++) {
    key.write(chars[random.nextInt(chars.length)]);
  }
  return key.toString();
}
