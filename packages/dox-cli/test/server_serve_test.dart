import 'package:dox/src/tools/server_serve.dart';
import 'package:test/test.dart';

void main() {
  test('build_runner runs without removed flags', () {
    expect(buildRunnerBuildArgs, <String>['run', 'build_runner', 'build']);
  });
}
