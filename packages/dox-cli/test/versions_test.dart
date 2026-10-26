import 'package:dox/src/tools/update_dox.dart';
import 'package:dox/src/utils/versions.dart';
import 'package:test/test.dart';

void main() {
  test('newest of the same major, pre-releases count', () {
    List<String> all = <String>[
      '2.0.1',
      '3.0.0-alpha.2',
      '3.0.0-alpha.10',
      '3.0.0-alpha.4',
      '4.0.0',
    ];
    expect(newestOfMajor(all, '3.0.0-alpha.4'), '3.0.0-alpha.10');
    expect(newestOfMajor(<String>[...all, '3.0.0'], '3.0.0-alpha.4'), '3.0.0');
    expect(newestOfMajor(all, '2.0.0'), '2.0.1');
    expect(newestOfMajor(all, '5.0.0'), isNull);
  });

  test('rc ranks above beta and alpha, whatever the number', () {
    List<String> all = <String>[
      '3.0.0-alpha.17',
      '3.0.0-rc.1',
      '3.0.0-beta.3',
      '3.0.0-alpha.9',
    ];
    expect(newestOfMajor(all, '3.0.0-rc.1'), '3.0.0-rc.1');
    expect(
      newestOfMajor(<String>[...all, '3.0.0-rc.2'], '3.0.0'),
      '3.0.0-rc.2',
    );
    expect(newestOfMajor(<String>[...all, '3.0.0'], '3.0.0-rc.1'), '3.0.0');
    expect(compareVersions('3.0.0-beta.3', '3.0.0-alpha.17'), greaterThan(0));
  });

  test('dox update reads the pub.dev versions, not the retracted ones', () {
    String json = '''
{"latest": {"version": "2.0.1"}, "versions": [
  {"version": "2.0.1"},
  {"version": "3.0.0-alpha.4"},
  {"version": "3.0.0-alpha.5", "retracted": true}
]}''';
    List<String> versions = pubVersions(json);
    expect(versions, <String>['2.0.1', '3.0.0-alpha.4']);
    expect(newestOfMajor(versions, '3.0.0-alpha.1'), '3.0.0-alpha.4');
  });
}
