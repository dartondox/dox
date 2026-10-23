import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  parseTests();

  setUpAll(() {
    Env().load();
    Env().env['EMPTY_KEY'] = '';
    Env().env['PORT_TEXT'] = '8080';
    Env().env['BAD_PORT'] = 'abc';
    Env().env['FLAG'] = 'yes';
  });

  test('ENV get key', () {
    String key = Env.get('APP_KEY');
    expect(key, '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt');
  });

  test('ENV get key which not exist', () {
    String key = Env.get('DB_NAME', 'postgres');
    expect(key, 'postgres');
  });

  test('missing key with no default is never the text "null"', () {
    String name = Env.get('DOX_MISSING_KEY');
    expect(name, '');
    expect(Env.get<String?>('DOX_MISSING_KEY'), isNull);
    expect(Env.get<dynamic>('DOX_MISSING_KEY'), isNull);
    expect(Env.get<String>('EMPTY_KEY'), '');
  });

  test('empty key uses the default', () {
    expect(Env.get('EMPTY_KEY', 'fallback'), 'fallback');
  });

  test('typed values', () {
    expect(Env.get<int>('PORT_TEXT'), 8080);
    expect(Env.get<int>('DOX_MISSING_KEY', 3000), 3000);
    expect(Env.get<num>('PORT_TEXT'), 8080);
    expect(Env.get<bool>('FLAG'), isTrue);
    expect(Env.get<bool>('DOX_MISSING_KEY', false), isFalse);
  });

  test('missing number with no default throws a clear error', () {
    expect(() => Env.get<int>('DOX_MISSING_KEY'), throwsArgumentError);
    expect(() => Env.get<int>('BAD_PORT'), throwsArgumentError);
  });

  test('empty APP_KEY fails at startup in production', () {
    Dox().config = AppConfig(appKey: '');
    Env().env['APP_ENV'] = 'production';
    expect(() => Dox().checkAppKey(), throwsStateError);
    Env().env['APP_ENV'] = 'development';
    expect(() => Dox().checkAppKey(), returnsNormally);
    Env().env.remove('APP_ENV');
  });
}

void parseTests() {
  test('.env: a # after a space is a comment', () {
    Map<String, String> env = Env.parse('''
# a comment line
APP_PORT=3000 # dev port
NAME=dox	# tab before the comment
EMPTY= # nothing
HASH=abc#def
QUOTED="a # b" # note
SINGLE='x#y'
URL=postgres://u:p@h/db?a=b
CRLF=yes\r
''');
    expect(env['APP_PORT'], '3000');
    expect(env['NAME'], 'dox');
    expect(env['EMPTY'], '');
    expect(env['HASH'], 'abc#def');
    expect(env['QUOTED'], 'a # b');
    expect(env['SINGLE'], 'x#y');
    expect(env['URL'], 'postgres://u:p@h/db?a=b');
    expect(env['CRLF'], 'yes');
    expect(env.containsKey('# a comment line'), isFalse);
  });
}
