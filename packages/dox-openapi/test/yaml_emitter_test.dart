import 'dart:convert';

import 'package:dox_openapi/dox_openapi.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Parses YAML and turns it into plain Dart maps and lists.
Object? parseBack(String text) {
  return jsonDecode(jsonEncode(loadYaml(text)));
}

void main() {
  YamlEmitter emitter = const YamlEmitter();

  group('YamlEmitter quoting', () {
    List<String> tricky = <String>[
      '',
      ' ',
      'plain text',
      'trailing ',
      ' leading',
      'true',
      'False',
      'null',
      'yes',
      'No',
      'on',
      'OFF',
      'y',
      '~',
      '123',
      '1.5',
      '0x1F',
      '1e3',
      '.inf',
      '.nan',
      '-1',
      '+1',
      'a: b',
      'a:b',
      'a #comment',
      '#hash',
      '- dash',
      '-',
      '?',
      '[list]',
      '{map}',
      '*alias',
      '&anchor',
      '!tag',
      '%directive',
      '@at',
      '`tick',
      '|',
      '>',
      "it's",
      'say "hi"',
      r'back\slash',
      'line1\nline2',
      'tab\there',
      'cr\rhere',
      'bell\u0007',
      'del\u007f',
      'c1\u0080',
      'bom﻿',
      'unicode: ünïcödé 😀',
      r'$ref',
      '#/components/schemas/User',
      '/users/{id}',
      '200',
      'application/json',
      'a,b',
      '---',
      '...',
    ];

    for (String value in tricky) {
      test('round trips ${jsonEncode(value)}', () {
        String yaml = emitter.emit(<String, dynamic>{value: value});
        expect(parseBack(yaml), <String, dynamic>{value: value});
      });
    }

    test('keeps safe words plain', () {
      expect(emitter.quote('hello world'), 'hello world');
      expect(emitter.quote('application/json'), 'application/json');
      expect(emitter.quote('Users_list-2.0'), 'Users_list-2.0');
      expect(emitter.quote('true'), '"true"');
      expect(emitter.quote('200'), '"200"');
    });
  });

  group('YamlEmitter structure', () {
    test('writes scalars of each type', () {
      Map<String, dynamic> data = <String, dynamic>{
        'int': 1,
        'negative': -5,
        'double': 2.5,
        'big': 1e21,
        'bool': true,
        'off': false,
        'nothing': null,
        'emptyMap': <String, dynamic>{},
        'emptyList': <dynamic>[],
      };
      expect(parseBack(emitter.emit(data)), data);
    });

    test('writes nested maps and lists', () {
      Map<String, dynamic> data = <String, dynamic>{
        'list': <dynamic>[
          1,
          'two',
          <String, dynamic>{'a': 1, 'b': <dynamic>[]},
          <dynamic>[
            <dynamic>[1, 2],
            <String, dynamic>{
              'deep': <String, dynamic>{'x': 'y'},
            },
          ],
          <String, dynamic>{
            'items': <dynamic>['a', 'b'],
            'more': <String, dynamic>{'c': null},
          },
        ],
        'map': <String, dynamic>{
          'inner': <String, dynamic>{
            'list': <dynamic>[
              <String, dynamic>{'k': 'v'},
            ],
          },
        },
      };
      expect(parseBack(emitter.emit(data)), data);
    });

    test('writes a top level scalar and empty collections', () {
      expect(emitter.emit('x'), 'x\n');
      expect(emitter.emit(<String, dynamic>{}), '{}\n');
      expect(emitter.emit(<dynamic>[]), '[]\n');
      expect(parseBack(emitter.emit(<dynamic>[1, 'a'])), <dynamic>[1, 'a']);
    });

    test('writes infinity and NaN as YAML floats', () {
      Object? back = loadYaml(
        emitter.emit(<String, dynamic>{
          'pos': double.infinity,
          'neg': double.negativeInfinity,
          'nan': double.nan,
        }),
      );
      Map<dynamic, dynamic> map = back as Map<dynamic, dynamic>;
      expect(map['pos'], double.infinity);
      expect(map['neg'], double.negativeInfinity);
      expect((map['nan'] as double).isNaN, isTrue);
    });

    test('rejects values that are not JSON', () {
      expect(
        () => emitter.emit(<String, dynamic>{'x': DateTime(2020)}),
        throwsArgumentError,
      );
    });
  });
}
