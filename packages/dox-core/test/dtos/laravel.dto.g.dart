// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'laravel.dto.dart';

// **************************************************************************
// DoxDtoGenerator
// **************************************************************************

// ignore_for_file: type=lint

/// The checks, the converter and the JSON Schema of [LaravelRules].
const DtoSchema<LaravelRules> $LaravelRulesDto = _$LaravelRulesDto();

class _$LaravelRulesDto extends DtoSchema<LaravelRules>
    implements JsonObjectWriter {
  const _$LaravelRulesDto();

  static const Map<String, String> _messages = <String, String>{};

  static const Map<String, String> _attributes = <String, String>{
    'first_name': 'first name',
  };

  @override
  Type get type => LaravelRules;

  @override
  String get name => 'LaravelRules';

  @override
  LaravelRules? convert(Object? input, DtoState state, List<Object> path) {
    state.attributes(path, _attributes);
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // firstName: String
    Object? firstName = state.string(
      state.read(input, 'first_name'),
      path,
      'first_name',
      _messages,
      trim: true,
    );
    if (firstName == null || firstName is Undefined)
      state.required(path, 'first_name', _messages);
    // age: int
    Object? age = state.integer(
      state.read(input, 'age'),
      path,
      'age',
      _messages,
      coerce: true,
    );
    if (age == null || age is Undefined) state.required(path, 'age', _messages);
    // terms: bool
    Object? terms = state.boolean(
      state.read(input, 'terms'),
      path,
      'terms',
      _messages,
      coerce: true,
    );
    if (terms == null || terms is Undefined)
      state.required(path, 'terms', _messages);
    // start: DateTime
    Object? start = state.date(
      state.read(input, 'start'),
      path,
      'start',
      _messages,
    );
    if (start == null || start is Undefined)
      state.required(path, 'start', _messages);
    // end: DateTime
    Object? end = state.date(state.read(input, 'end'), path, 'end', _messages);
    if (end == null || end is Undefined) state.required(path, 'end', _messages);
    // type: String?
    Object? type = state.string(
      state.read(input, 'type'),
      path,
      'type',
      _messages,
      trim: true,
    );
    // company: String?
    Object? company = state.string(
      state.read(input, 'company'),
      path,
      'company',
      _messages,
      trim: true,
    );
    // vat: String?
    Object? vat;
    bool vatExcluded = const ExcludeIf('type', 'person').appliesTo(input);
    if (vatExcluded) {
      vat = undefined;
    } else {
      vat = state.string(
        state.read(input, 'vat'),
        path,
        'vat',
        _messages,
        trim: true,
      );
    }
    // debug: String?
    Object? debug = state.string(
      state.read(input, 'debug'),
      path,
      'debug',
      _messages,
      trim: true,
    );
    // nick: String?
    Object? nick = state.string(
      state.read(input, 'nick'),
      path,
      'nick',
      _messages,
      trim: true,
    );
    // id: String?
    Object? id = state.string(
      state.read(input, 'id'),
      path,
      'id',
      _messages,
      trim: true,
    );
    // max: int?
    Object? max = state.integer(
      state.read(input, 'max'),
      path,
      'max',
      _messages,
      coerce: true,
    );
    state.requiredWhen(
      const RequiredUnless('type', 'person'),
      company,
      input,
      path,
      'company',
      _messages,
    );
    state.requiredWhen(
      const Prohibited(),
      debug,
      input,
      path,
      'debug',
      _messages,
    );
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (terms is bool) {
      if (!(const Accepted().check(
        terms,
        state.context(path, 'terms', terms),
      ))) {
        state.failRule(const Accepted(), path, 'terms', terms, _messages);
      }
    }
    if (end is DateTime) {
      if (!(start is! DateTime || end.isAfter(start))) {
        state.fail(
          path,
          'end',
          IssueCodes.after,
          DefaultMessages.after,
          end,
          params: const <String, Object?>{'date': 'start'},
          messages: _messages,
        );
      }
    }
    if (vat is String) {
      if (!(vat.runes.length >= 3)) {
        state.fail(
          path,
          'vat',
          IssueCodes.minLength,
          DefaultMessages.minLength,
          vat,
          params: const <String, Object?>{'min': 3},
          messages: _messages,
        );
      }
    }
    if (nick is String) {
      if (!(const Different('first_name')
          .check(nick, state.context(path, 'nick', nick)))) {
        state.failRule(
          const Different('first_name'),
          path,
          'nick',
          nick,
          _messages,
        );
      }
    }
    if (id is String) {
      if (!(const Ulid().check(id, state.context(path, 'id', id)))) {
        state.failRule(const Ulid(), path, 'id', id, _messages);
      }
    }
    if (max is int) {
      if (!(const GreaterThanField('age')
          .check(max, state.context(path, 'max', max)))) {
        state.failRule(
          const GreaterThanField('age'),
          path,
          'max',
          max,
          _messages,
        );
      }
    }
    if (state.issues.length != issuesBefore) return null;
    return LaravelRules(
      firstName: firstName as String,
      age: age as int,
      terms: terms as bool,
      start: start as DateTime,
      end: end as DateTime,
      type: type is Undefined ? null : type as String?,
      company: company is Undefined ? null : company as String?,
      vat: vat is Undefined ? null : vat as String?,
      debug: debug is Undefined ? null : debug as String?,
      nick: nick is Undefined ? null : nick as String?,
      id: id is Undefined ? null : id as String?,
      max: max is Undefined ? null : max as int?,
    );
  }

  @override
  LaravelRules fromMap(Map<String, dynamic> map) {
    return LaravelRules(
      firstName: map['first_name'] as String,
      age: (map['age'] as num).toInt(),
      terms: map['terms'] as bool,
      start: DateTime.parse(map['start'] as String).toUtc(),
      end: DateTime.parse(map['end'] as String).toUtc(),
      type: map['type'] == null ? null : (map['type'] as String),
      company: map['company'] == null ? null : (map['company'] as String),
      vat: map['vat'] == null ? null : (map['vat'] as String),
      debug: map['debug'] == null ? null : (map['debug'] as String),
      nick: map['nick'] == null ? null : (map['nick'] as String),
      id: map['id'] == null ? null : (map['id'] as String),
      max: map['max'] == null ? null : ((map['max'] as num).toInt()),
    );
  }

  @override
  Map<String, dynamic> toMap(LaravelRules dto) {
    return <String, dynamic>{
      'first_name': dto.firstName,
      'age': dto.age,
      'terms': dto.terms,
      'start': dto.start.toIso8601String(),
      'end': dto.end.toIso8601String(),
      'type': dto.type,
      'company': dto.company,
      'vat': dto.vat,
      'debug': dto.debug,
      'nick': dto.nick,
      'id': dto.id,
      'max': dto.max,
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as LaravelRules));

  @override
  Map<String, dynamic> toJsonSchema() {
    Map<String, dynamic> schema = <String, dynamic>{
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
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'terms',
    ], const Accepted().toJsonSchema());
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'nick',
    ], const Different('first_name').toJsonSchema());
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'id',
    ], const Ulid().toJsonSchema());
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'max',
    ], const GreaterThanField('age').toJsonSchema());
    return schema;
  }
}
