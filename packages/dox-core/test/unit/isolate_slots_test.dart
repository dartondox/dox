import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/processors.dart' as impl;
import 'package:test/test.dart';

/// keeps what is written to it, to read the stderr lines
class _Capture implements Stdout {
  final StringBuffer text = StringBuffer();

  @override
  void writeln([Object? object = '']) => text.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// the stderr text of [Dox.warnIsolateSlots]
String warning(int isolates, int slots) {
  _Capture err = _Capture();
  IOOverrides.runZoned(() {
    Dox().warnIsolateSlots(isolates, slots);
  }, stderr: () => err);
  return err.text.toString();
}

void main() {
  group('IsolateSlots.fromOptions', () {
    test('no flag gives the VM default: 8 slots', () {
      expect(impl.IsolateSlots.fromOptions(''), 8);
      expect(impl.IsolateSlots.fromOptions('--verbose_gc'), 8);
    });

    test('the flag gives MB / 2 slots', () {
      expect(impl.IsolateSlots.fromOptions('--new_gen_semi_max_size=128'), 64);
      expect(
        impl.IsolateSlots.fromOptions(
          '--verbose_gc,--new_gen_semi_max_size=32',
        ),
        16,
      );
    });

    test('the last flag wins', () {
      expect(
        impl.IsolateSlots.fromOptions(
          '--new_gen_semi_max_size=4,--new_gen_semi_max_size=64',
        ),
        32,
      );
    });

    test('never below 1 slot', () {
      expect(impl.IsolateSlots.fromOptions('--new_gen_semi_max_size=1'), 1);
      expect(impl.IsolateSlots.fromOptions('--new_gen_semi_max_size=0'), 1);
    });
  });

  test('megabytesFor gives a size with one slot per isolate', () {
    int megabytes = impl.IsolateSlots.megabytesFor(64);
    expect(megabytes, 128);
    expect(
      impl.IsolateSlots.fromOptions('--new_gen_semi_max_size=$megabytes'),
      64,
    );
  });

  group('warnIsolateSlots', () {
    test('no warning when every isolate has a slot', () {
      expect(warning(8, 8), isEmpty);
      expect(warning(4, 8), isEmpty);
    });

    test('warns with the flag to set when isolates wait', () {
      String text = warning(16, 8);
      expect(text, contains('16 isolates'));
      expect(text, contains('DART_VM_OPTIONS=--new_gen_semi_max_size=32'));
    });
  });
}
