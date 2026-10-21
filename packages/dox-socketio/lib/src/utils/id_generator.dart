import 'dart:convert';
import 'dart:math';

/// Makes random ids for sessions and sockets.
///
/// The ids are 20 url-safe base64 characters, like the Node.js server.
class IdGenerator {
  IdGenerator([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  /// Returns a new random id.
  String next() {
    List<int> bytes = List<int>.generate(15, _randomByte);
    return base64Url.encode(bytes);
  }

  int _randomByte(int _) => _random.nextInt(256);
}
