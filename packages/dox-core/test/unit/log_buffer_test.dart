import 'package:dox_core/utils/log_buffer.dart';
import 'package:test/test.dart';

void main() {
  late List<String> writes;

  setUp(() {
    writes = <String>[];
    LogBuffer.writer = writes.add;
  });

  tearDown(() {
    LogBuffer.flush();
  });

  group('LogBuffer |', () {
    test('lines are written together after about 20 ms', () async {
      LogBuffer.write('a');
      LogBuffer.write('b');
      expect(writes, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(writes, <String>['a\nb\n']);
    });

    test('a buffer over 64 KB is written at once', () {
      LogBuffer.write('x' * 60000);
      expect(writes, isEmpty);
      LogBuffer.write('y' * 6000);
      expect(writes.length, 1);
      expect(writes.single, endsWith('y\n'));
    });

    test('now writes at once, in order', () {
      LogBuffer.write('1');
      LogBuffer.write('2', now: true);
      expect(writes, <String>['1\n2\n']);
    });

    test('flush with nothing waiting writes nothing', () {
      LogBuffer.flush();
      expect(writes, isEmpty);
    });
  });
}
