import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

import '../utils/test_app_key.dart';

/// keeps what is written to it, to read the stderr lines
class _Capture implements Stdout {
  final StringBuffer text = StringBuffer();

  @override
  void writeln([Object? object = '']) => text.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

AppConfig config(CORSConfig cors) {
  return AppConfig(appKey: testAppKey, cors: cors);
}

/// the stderr lines of [Dox.warnCorsCredentials]
List<String> warnings() {
  _Capture err = _Capture();
  IOOverrides.runZoned(Dox().warnCorsCredentials, stderr: () => err);
  return err.text
      .toString()
      .split('\n')
      .where((String l) => l.isNotEmpty)
      .toList();
}

void main() {
  test('no warning for a listed origin with credentials', () {
    Dox().initialize(
      config(
        const CORSConfig(
          origin: <String>['https://app.example.com'],
          credentials: true,
        ),
      ),
    );
    expect(warnings(), isEmpty);
  });

  test('no warning for * with no credentials', () {
    Dox().initialize(config(const CORSConfig(origin: '*')));
    expect(warnings(), isEmpty);
  });

  test('one warning for * in a list with credentials, only once', () {
    Dox().initialize(
      config(const CORSConfig(origin: <String>['*'], credentials: true)),
    );
    expect(warnings(), <String>[Dox.corsCredentialsWarning]);
    expect(warnings(), isEmpty);
  });
}
