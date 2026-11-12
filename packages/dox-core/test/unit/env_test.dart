import 'dart:io';

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

  test('KEY= in the .env file gives the default', () {
    Env().env.addAll(Env.parse('DOX_EMPTY_IN_FILE=\nexport DOX_EMPTY_2=""\n'));
    expect(Env().env['DOX_EMPTY_IN_FILE'], '');
    expect(Env.get('DOX_EMPTY_IN_FILE', 'fallback'), 'fallback');
    expect(Env.get<int>('DOX_EMPTY_2', 5), 5);
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

  test('wrong size or public APP_KEY fails at startup outside development', () {
    for (String key in <String>[
      'short-key',
      // longer keys too: the rule is exactly 32 characters
      '832b1c5fb42a3e48e3167d3ad7d77b241e28fca0d5a7f931',
      '832b1c5fb42a3e48e3167d3ad7d77b241e28fca0d5a7f931832b1c5fb42a3e48',
      'ZrNbOZJAjC2MDzqehhsGV2DzFFI4pz5R',
      'KKep5qC6uHlAgrwaQTQewgMRSIqQnoj0',
    ]) {
      Dox().config = AppConfig(appKey: key);
      Env().env.remove('APP_ENV');
      expect(() => Dox().checkAppKey(), throwsStateError);
      Env().env['APP_ENV'] = 'staging';
      expect(() => Dox().checkAppKey(), throwsStateError);
      for (String env in <String>['development', 'local', 'test', 'testing']) {
        Env().env['APP_ENV'] = env;
        expect(() => Dox().checkAppKey(), returnsNormally);
      }
    }
    Dox().config = AppConfig(appKey: '4HyiSrq4N5Nfg6bOadIhbFEI8zbUkpxt');
    Env().env.remove('APP_ENV');
    expect(() => Dox().checkAppKey(), returnsNormally);
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

  test('.env: export KEY=value', () {
    Map<String, String> env = Env.parse(
      'export A=1\nexport   B="two"\nexport=3\nexporter=4\n',
    );
    expect(env, <String, String>{
      'A': '1',
      'B': 'two',
      'export': '3',
      'exporter': '4',
    });
  });

  test('.env: escapes in double quotes, single quotes stay raw', () {
    Map<String, String> env = Env.parse(r"""
LINES="a\nb\tc"
QUOTE="say \"hi\" # not a comment" # comment
SLASH="C:\\dir\x"
DOLLAR="\${HOME}"
RAW='a\nb ${HOME}'
TICK=`a\nb`
OPEN="no end
""", expand: true);
    expect(env['LINES'], 'a\nb\tc');
    expect(env['QUOTE'], 'say "hi" # not a comment');
    expect(env['SLASH'], r'C:\dir\x');
    expect(env['DOLLAR'], r'${HOME}');
    expect(env['RAW'], r'a\nb ${HOME}');
    expect(env['TICK'], r'a\nb');
    expect(env['OPEN'], '"no end');
  });

  test(r'.env: ${OTHER} expansion', () {
    String home = Platform.environment['HOME'] ?? '';
    Map<String, String> env = Env.parse(
      r"""
DOX_HOST=localhost
DOX_PORT=5432
URL=postgres://${DOX_HOST}:${DOX_PORT}/db # comment
QUOTED="${DOX_HOST}:${DOX_PORT}"
SINGLE='${DOX_HOST}'
UNKNOWN=${DOX_NOT_SET_ANYWHERE}/x
BAD=${1X} ${} $DOX_HOST
LATER=${DOX_DEFINED_BELOW}
DOX_DEFINED_BELOW=yes
HOME=from-file
REAL=${HOME}
""",
      known: <String, String>{'DOX_KNOWN': 'k'},
      expand: true,
    );
    expect(env['URL'], 'postgres://localhost:5432/db');
    expect(env['QUOTED'], 'localhost:5432');
    expect(env['SINGLE'], r'${DOX_HOST}');
    expect(env['UNKNOWN'], r'${DOX_NOT_SET_ANYWHERE}/x');
    expect(env['BAD'], r'${1X} ${} $DOX_HOST');
    expect(env['LATER'], r'${DOX_DEFINED_BELOW}');
    // a real environment variable wins over the file
    if (home.isNotEmpty) expect(env['REAL'], home);
    expect(
      Env.parse(
        r'A=${DOX_KNOWN}',
        known: <String, String>{'DOX_KNOWN': 'k'},
        expand: true,
      )['A'],
      'k',
    );
  });

  test(r'.env: self reference and cycles do not hang', () {
    Map<String, String> env = Env.parse(r'''
SELF=${SELF}
DOX_A=${DOX_B}
DOX_B=${DOX_A}
LIST=a
LIST=${LIST}:b
LIST=${LIST}:c
''', expand: true);
    expect(env['SELF'], r'${SELF}');
    expect(env['DOX_A'], r'${DOX_B}');
    expect(env['DOX_B'], r'${DOX_B}');
    expect(env['LIST'], 'a:b:c');
  });

  test('.env: envExpand off reads values as they are written', () {
    Map<String, String> env = Env.parse(r'''
DOX_X=1
PATH_DIR="C:\new"
QUOTE="say \"hi\""
LITERAL=${DOX_X}
QUOTED_LITERAL="${DOX_X}"
export EXPORTED=yes
''');
    expect(env['PATH_DIR'], r'C:\new');
    expect(env['QUOTE'], r'say \');
    expect(env['LITERAL'], r'${DOX_X}');
    expect(env['QUOTED_LITERAL'], r'${DOX_X}');
    expect(env['EXPORTED'], 'yes');
  });
}
