import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as sio;
import 'package:test/test.dart';

import 'support/test_app.dart';

/// Uses the Dart `socket_io_client` package against the server.
void main() {
  late TestApp app;

  setUp(() async {
    app = TestApp();
    await app.start();
  });

  tearDown(() => app.stop());

  // The package only supports websocket on the Dart VM (see its README).
  for (String transport in <String>['websocket']) {
    test('connect, emit with ack and receive over $transport', () async {
      sio.Socket socket = sio.io(
        app.url,
        sio.OptionBuilder()
            .setTransports(<String>[transport])
            .disableAutoConnect()
            .disableReconnection()
            .enableForceNew()
            .build(),
      );
      Completer<Object?> welcome = Completer<Object?>();
      socket.on('welcome', welcome.complete);
      socket.connect();
      Map<dynamic, dynamic> data = await welcome.future.timeout(
        Duration(seconds: 5),
      ) as Map<dynamic, dynamic>;
      expect(data['id'], socket.id);

      Completer<Object?> echo = Completer<Object?>();
      socket.emitWithAck('echo', 'from dart', ack: echo.complete);
      expect(await echo.future.timeout(Duration(seconds: 5)), 'from dart');

      Completer<Object?> admin = Completer<Object?>();
      sio.Socket adminSocket = sio.io(
        '${app.url}/admin',
        sio.OptionBuilder()
            .setTransports(<String>[transport])
            .setAuth(<String, String>{'token': 'secret'})
            .disableReconnection()
            .enableForceNew()
            .build(),
      );
      adminSocket.onConnect(admin.complete);
      await admin.future.timeout(Duration(seconds: 5));

      socket.dispose();
      adminSocket.dispose();
    });
  }
}
