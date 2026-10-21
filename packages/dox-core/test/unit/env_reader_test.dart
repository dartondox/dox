import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

enum Level { debug, info }

EnvReader reader(
  Map<String, String> dotEnv, [
  Map<String, String> environment = const <String, String>{},
]) {
  return EnvReader(environment: environment, dotEnv: dotEnv);
}

void main() {
  group('EnvReader |', () {
    test('converts types', () {
      EnvReader r = reader(<String, String>{
        'PORT': '3000',
        'RATE': '0.5',
        'RATIO': '2',
        'DEBUG': 'yes',
        'OFF': '0',
        'URL': 'https://dox.dev/a',
        'LEVEL': 'INFO',
        'HOSTS': 'a, b,,c ',
      });
      expect(r.integer('PORT'), 3000);
      expect(r.decimal('RATE'), 0.5);
      expect(r.number('RATIO'), 2);
      expect(r.boolean('DEBUG'), isTrue);
      expect(r.boolean('OFF'), isFalse);
      expect(r.uri('URL')!.host, 'dox.dev');
      expect(r.enumByName('LEVEL', Level.values), Level.info);
      expect(r.list('HOSTS'), <String>['a', 'b', 'c']);
      r.check();
    });

    test('durations', () {
      EnvReader r = reader(<String, String>{
        'A': '300',
        'B': '500ms',
        'C': '30s',
        'D': '5m',
        'E': '2h',
        'F': '1d',
      });
      expect(r.duration('A'), const Duration(minutes: 5));
      expect(r.duration('B'), const Duration(milliseconds: 500));
      expect(r.duration('C'), const Duration(seconds: 30));
      expect(r.duration('D'), const Duration(minutes: 5));
      expect(r.duration('E'), const Duration(hours: 2));
      expect(r.duration('F'), const Duration(days: 1));
    });

    test('missing and empty give null (optional)', () {
      EnvReader r = reader(<String, String>{'EMPTY': '', 'NULL': 'null'});
      expect(r.string('NONE'), isNull);
      expect(r.string('EMPTY'), isNull);
      expect(r.integer('NULL'), isNull);
      r.check();
    });

    test('real environment wins over .env', () {
      EnvReader r = reader(
        <String, String>{'APP_NAME': 'from-file'},
        <String, String>{'APP_NAME': 'from-env'},
      );
      expect(r.string('APP_NAME'), 'from-env');
    });

    test('check lists every missing and bad key', () {
      EnvReader r = reader(<String, String>{
        'PORT': 'abc',
        'DEBUG': 'maybe',
        'TTL': '5 years',
        'LEVEL': 'loud',
      });
      r.integer('PORT');
      r.boolean('DEBUG');
      r.duration('TTL');
      r.enumByName('LEVEL', Level.values);
      r.need('APP_KEY');
      r.need('PORT');
      expect(
        r.check,
        throwsA(
          isA<EnvException>().having(
            (EnvException e) => e.errors,
            'errors',
            <Matcher>[
              contains('PORT must be an int, not "abc"'),
              contains('DEBUG must be a bool'),
              contains('TTL must be a Duration'),
              contains('LEVEL must be one of debug, info'),
              equals('APP_KEY is missing'),
            ],
          ),
        ),
      );
    });
  });
}
