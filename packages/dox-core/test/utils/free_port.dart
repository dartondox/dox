import 'dart:io';

/// A port that is free now. The OS picks it.
///
/// Most tests start the server on port 0 and read the real port after.
/// Use this one only when the port must be known before the start, like
/// when many isolates or a child process share one port.
// ponytail: another program can take the port between close and bind.
// The OS gives free ports in turn, so this is rare.
Future<int> freePort() async {
  ServerSocket socket = await ServerSocket.bind(InternetAddress.anyIPv6, 0);
  int port = socket.port;
  await socket.close();
  return port;
}
