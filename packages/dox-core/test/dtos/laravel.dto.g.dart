// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'laravel.dto.dart';

// **************************************************************************
// DoxDtoGenerator
// **************************************************************************

// ignore_for_file: type=lint

/// The checks, the converter and the JSON Schema of [LaravelRules].
const DtoSchema<LaravelRules> $LaravelRulesDto = _$LaravelRulesDto();

class _$LaravelRulesDto extends DtoSchema<LaravelRules> {
  const _$LaravelRulesDto();

  static const Map<String, String> _m = <String, String>{};

  static const Map<String, String> _a = <String, String>{
    'first_name': 'first name',
  };

  @override
  Type get type => LaravelRules;

  @override
  String get name => 'LaravelRules';

  @override
  LaravelRules? convert(Object? input, DtoState s, List<Object> p) {
    s.attributes(p, _a);
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // firstName: String
    Object? c0;
    c0 = s.string(s.read(input, 'first_name'), p, 'first_name', _m, trim: true);
    if (c0 == null || c0 is Undefined) s.required(p, 'first_name', _m);
    // age: int
    Object? c1;
    c1 = s.integer(s.read(input, 'age'), p, 'age', _m, coerce: true);
    if (c1 == null || c1 is Undefined) s.required(p, 'age', _m);
    // terms: bool
    Object? c2;
    c2 = s.boolean(s.read(input, 'terms'), p, 'terms', _m, coerce: true);
    if (c2 == null || c2 is Undefined) s.required(p, 'terms', _m);
    // start: DateTime
    Object? c3;
    c3 = s.date(s.read(input, 'start'), p, 'start', _m);
    if (c3 == null || c3 is Undefined) s.required(p, 'start', _m);
    // end: DateTime
    Object? c4;
    c4 = s.date(s.read(input, 'end'), p, 'end', _m);
    if (c4 == null || c4 is Undefined) s.required(p, 'end', _m);
    // type: String?
    Object? c5;
    c5 = s.string(s.read(input, 'type'), p, 'type', _m, trim: true);
    // company: String?
    Object? c6;
    c6 = s.string(s.read(input, 'company'), p, 'company', _m, trim: true);
    // vat: String?
    Object? c7;
    bool x7 = const ExcludeIf('type', 'person').appliesTo(input);
    if (x7) {
      c7 = undefined;
    } else {
      c7 = s.string(s.read(input, 'vat'), p, 'vat', _m, trim: true);
    }
    // debug: String?
    Object? c8;
    c8 = s.string(s.read(input, 'debug'), p, 'debug', _m, trim: true);
    // nick: String?
    Object? c9;
    c9 = s.string(s.read(input, 'nick'), p, 'nick', _m, trim: true);
    // id: String?
    Object? c10;
    c10 = s.string(s.read(input, 'id'), p, 'id', _m, trim: true);
    // max: int?
    Object? c11;
    c11 = s.integer(s.read(input, 'max'), p, 'max', _m, coerce: true);
    s.requiredWhen(
      const RequiredUnless('type', 'person'),
      c6,
      input,
      p,
      'company',
      _m,
    );
    s.requiredWhen(const Prohibited(), c8, input, p, 'debug', _m);
    if (s.issues.length != e && !s.allErrors) return null;
    if (c2 is bool) {
      if (!(const Accepted().check(c2, s.context(p, 'terms', c2)))) {
        s.failRule(const Accepted(), p, 'terms', c2, _m);
      }
    }
    if (c4 is DateTime) {
      if (!(c3 is! DateTime || c4.isAfter(c3))) {
        s.fail(
          p,
          'end',
          IssueCodes.after,
          DefaultMessages.after,
          c4,
          params: const <String, Object?>{'date': 'start'},
          messages: _m,
        );
      }
    }
    if (c7 is String) {
      if (!(c7.runes.length >= 3)) {
        s.fail(
          p,
          'vat',
          IssueCodes.minLength,
          DefaultMessages.minLength,
          c7,
          params: const <String, Object?>{'min': 3},
          messages: _m,
        );
      }
    }
    if (c9 is String) {
      if (!(const Different('first_name')
          .check(c9, s.context(p, 'nick', c9)))) {
        s.failRule(const Different('first_name'), p, 'nick', c9, _m);
      }
    }
    if (c10 is String) {
      if (!(const Ulid().check(c10, s.context(p, 'id', c10)))) {
        s.failRule(const Ulid(), p, 'id', c10, _m);
      }
    }
    if (c11 is int) {
      if (!(const GreaterThanField('age')
          .check(c11, s.context(p, 'max', c11)))) {
        s.failRule(const GreaterThanField('age'), p, 'max', c11, _m);
      }
    }
    if (s.issues.length != e) return null;
    return LaravelRules(
      firstName: c0 as String,
      age: c1 as int,
      terms: c2 as bool,
      start: c3 as DateTime,
      end: c4 as DateTime,
      type: c5 is Undefined ? null : c5 as String?,
      company: c6 is Undefined ? null : c6 as String?,
      vat: c7 is Undefined ? null : c7 as String?,
      debug: c8 is Undefined ? null : c8 as String?,
      nick: c9 is Undefined ? null : c9 as String?,
      id: c10 is Undefined ? null : c10 as String?,
      max: c11 is Undefined ? null : c11 as int?,
    );
  }

  @override
  LaravelRules fromMap(Map<String, dynamic> m) {
    return LaravelRules(
      firstName: m['first_name'] as String,
      age: (m['age'] as num).toInt(),
      terms: m['terms'] as bool,
      start: DateTime.parse(m['start'] as String).toUtc(),
      end: DateTime.parse(m['end'] as String).toUtc(),
      type: m['type'] == null ? null : (m['type'] as String),
      company: m['company'] == null ? null : (m['company'] as String),
      vat: m['vat'] == null ? null : (m['vat'] as String),
      debug: m['debug'] == null ? null : (m['debug'] as String),
      nick: m['nick'] == null ? null : (m['nick'] as String),
      id: m['id'] == null ? null : (m['id'] as String),
      max: m['max'] == null ? null : ((m['max'] as num).toInt()),
    );
  }

  @override
  Map<String, dynamic> toMap(LaravelRules o) {
    String f0 = o.firstName;
    int f1 = o.age;
    bool f2 = o.terms;
    DateTime f3 = o.start;
    DateTime f4 = o.end;
    String? f5 = o.type;
    String? f6 = o.company;
    String? f7 = o.vat;
    String? f8 = o.debug;
    String? f9 = o.nick;
    String? f10 = o.id;
    int? f11 = o.max;
    return <String, dynamic>{
      'first_name': f0,
      'age': f1,
      'terms': f2,
      'start': f3.toIso8601String(),
      'end': f4.toIso8601String(),
      'type': f5,
      'company': f6,
      'vat': f7,
      'debug': f8,
      'nick': f9,
      'id': f10,
      'max': f11,
    };
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    Map<String, dynamic> j = <String, dynamic>{
      'type': 'object',
      'title': 'LaravelRules',
      'properties': <String, dynamic>{
        'first_name': <String, dynamic>{'type': 'string'},
        'age': <String, dynamic>{'type': 'integer'},
        'terms': <String, dynamic>{'type': 'boolean'},
        'start': <String, dynamic>{'type': 'string', 'format': 'date-time'},
        'end': <String, dynamic>{'type': 'string', 'format': 'date-time'},
        'type': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'company': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'vat': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'minLength': 3,
        },
        'debug': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'nick': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'id': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'max': <String, dynamic>{
          'type': <dynamic>['integer', 'null'],
        },
      },
      'required': <dynamic>['first_name', 'age', 'terms', 'start', 'end'],
    };
    JsonSchemaTools.merge(j, <String>[
      'properties',
      'terms',
    ], const Accepted().toJsonSchema());
    JsonSchemaTools.merge(j, <String>[
      'properties',
      'nick',
    ], const Different('first_name').toJsonSchema());
    JsonSchemaTools.merge(j, <String>[
      'properties',
      'id',
    ], const Ulid().toJsonSchema());
    JsonSchemaTools.merge(j, <String>[
      'properties',
      'max',
    ], const GreaterThanField('age').toJsonSchema());
    return j;
  }
}
