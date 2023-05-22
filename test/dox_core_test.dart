import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import 'core/config/app.dart';
import 'core/http.dart';
import 'core/websocket.dart';

Config config = Config();
Dox dox = Dox();

void main() {
  group('Http', () {
    setUpAll(() async {
      dox.websocket(websocket: DoxWebsocket());
      dox.initialize(Config());
      await Future.delayed(Duration(milliseconds: 500));
    });

    httpTest();
    websocketTest();

    tearDownAll(() {
      dox.server.close();
    });
  });
}
