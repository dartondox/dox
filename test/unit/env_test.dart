import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  test('ENV get key', () {
    Env.load();
    String key = Env.get('APP_KEY');
    expect(key, '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt');
  });

  test('ENV get key which not exist', () {
    Env.load();
    String key = Env.get('DB_NAME', 'postgres');
    expect(key, 'postgres');
  });
}
