import 'package:dox_builder/src/util.dart';
import 'package:test/test.dart';

void main() {
  group('safeLocal |', () {
    test('a free name stays as it is', () {
      expect(safeLocal('name', <String>{'input'}), 'name');
    });

    test('a taken name gets the suffix Value, then a number', () {
      Set<String> taken = <String>{'state', 'stateValue'};
      expect(safeLocal('state', taken), 'stateValue2');
      expect(taken, contains('stateValue2'));
    });

    test('a Dart keyword gets the suffix', () {
      expect(safeLocal('late', <String>{}), 'lateValue');
    });

    test('a short name with digits gets the suffix', () {
      expect(safeLocal('x0', <String>{}), 'x0Value');
      expect(safeLocal('q10', <String>{}), 'q10Value');
      expect(safeLocal('x', <String>{}), 'x');
    });

    test('the same name two times gives two names', () {
      Set<String> taken = <String>{};
      expect(safeLocal('a', taken), 'a');
      expect(safeLocal('a', taken), 'aValue');
    });
  });
}
