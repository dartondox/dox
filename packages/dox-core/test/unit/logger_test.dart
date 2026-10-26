import 'dart:async';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

/// run [body] and return what it printed
List<String> _printed(void Function() body) {
  List<String> lines = <String>[];
  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        lines.add(line);
      },
    ),
  );
  return lines;
}

void main() {
  group('Logger |', () {
    test('level hides lower lines', () {
      Dox().config = AppConfig(
        appKey: 'x',
        logger: const LoggerConfig(enabled: true, level: 'warn'),
      );
      List<String> lines = _printed(() {
        Logger.info('info line');
        Logger.success('success line');
        Logger.warn('warn line');
        Logger.danger('danger line');
      });
      expect(lines.length, 2);
      expect(lines[0], contains('warn line'));
      expect(lines[1], contains('danger line'));
    });

    test('shouldLog', () {
      expect(Logger.shouldLog('info', 'info'), isTrue);
      expect(Logger.shouldLog('success', 'info'), isTrue);
      expect(Logger.shouldLog('info', 'debug'), isTrue);
      expect(Logger.shouldLog('info', 'ERROR'), isFalse);
      expect(Logger.shouldLog('danger', 'error'), isTrue);
      expect(Logger.shouldLog('warn', 'warning'), isTrue);
      // unknown setting: print everything
      expect(Logger.shouldLog('info', 'loud'), isTrue);
    });
  });
}
