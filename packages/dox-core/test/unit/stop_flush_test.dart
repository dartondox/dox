import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/log_buffer.dart';
import 'package:test/test.dart';

void main() {
  group('stop without a server |', () {
    // no server was started here, so `stopIsolate` throws at once
    test('the lines are still written when shutdown throws', () async {
      List<String> written = <String>[];
      LogBuffer.writer = written.add;
      addTearDown(() => LogBuffer.writer = stdout.write);
      LogBuffer.write('before error');
      await expectLater(Dox().stopIsolate(), throwsA(anything));
      expect(written.join(), contains('before error'));
    });

    test('stop writes the lines when it throws', () async {
      List<String> written = <String>[];
      LogBuffer.writer = written.add;
      addTearDown(() => LogBuffer.writer = stdout.write);
      LogBuffer.write('before stop error');
      await expectLater(Dox().stop(), throwsA(anything));
      expect(written.join(), contains('before stop error'));
    });
  });
}
