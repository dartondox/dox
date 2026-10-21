// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rules.dto.dart';

// **************************************************************************
// DoxDtoGenerator
// **************************************************************************

// ignore_for_file: type=lint

/// The checks, the converter and the JSON Schema of [CreateUser].
const DtoSchema<CreateUser> $CreateUserDto = _$CreateUserDto();

class _$CreateUserDto extends DtoSchema<CreateUser> {
  const _$CreateUserDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => CreateUser;

  @override
  String get name => 'CreateUser';

  @override
  CreateUser? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // name: String
    Object? c0;
    c0 = s.string(s.read(input, 'name'), p, 'name', _m, trim: true);
    if (c0 == null || c0 is Undefined) s.required(p, 'name', _m);
    // email: String
    Object? c1;
    c1 = s.string(s.read(input, 'email'), p, 'email', _m);
    if (c1 == null || c1 is Undefined) s.required(p, 'email', _m);
    // age: int?
    Object? c2;
    c2 = s.integer(s.read(input, 'age'), p, 'age', _m);
    // role: Role
    Object? c3;
    c3 = s.enumName(s.read(input, 'role'), p, 'role', _m, const <String>[
      'admin',
      'user',
    ]);
    if (c3 is String) {
      c3 = switch (c3) {
        'admin' => Role.admin,
        _ => Role.user,
      };
    }
    if (c3 == null) s.required(p, 'role', _m);
    // tags: List<String>
    Object? c4;
    c4 = s.list(s.read(input, 'tags'), p, 'tags', _m);
    if (c4 is List) {
      List<Object> q0 = <Object>[...p, 'tags'];
      List<String> o0 = <String>[];
      for (int i0 = 0; i0 < c4.length; i0++) {
        Object? x0;
        x0 = s.string(c4[i0], q0, i0, _m);
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as String);
        }
      }
      c4 = o0;
    }
    if (c4 == null) s.required(p, 'tags', _m);
    if (s.issues.length != e) return null;
    if (c0 is String) {
      if (!(c0.runes.length >= 3 && c0.runes.length <= 50)) {
        s.fail(
          p,
          'name',
          IssueCodes.lengthBetween,
          DefaultMessages.lengthBetween,
          c0,
          params: const <String, Object?>{'min': 3, 'max': 50},
          messages: _m,
        );
      }
    }
    if (c1 is String) {
      if (!(Patterns.email.hasMatch(c1))) {
        s.fail(
          p,
          'email',
          IssueCodes.email,
          DefaultMessages.email,
          c1,
          messages: _m,
        );
      }
    }
    if (c2 is int) {
      if (!(c2 >= 18)) {
        s.fail(
          p,
          'age',
          IssueCodes.min,
          DefaultMessages.min,
          c2,
          params: const <String, Object?>{'min': 18},
          messages: _m,
        );
      }
    }
    if (c4 is List<String>) {
      if (!(c4.length <= 5)) {
        s.fail(
          p,
          'tags',
          IssueCodes.maxItems,
          DefaultMessages.maxItems,
          c4,
          params: const <String, Object?>{'max': 5},
          messages: _m,
        );
      }
    }
    if (s.issues.length != e) return null;
    return CreateUser(
      name: c0 as String,
      email: c1 as String,
      age: c2 is Undefined ? null : c2 as int?,
      role: c3 is Undefined ? Role.user : c3 as Role,
      tags: c4 is Undefined ? const <String>[] : c4 as List<String>,
    );
  }

  @override
  CreateUser fromMap(Map<String, dynamic> m) {
    return CreateUser(
      name: m['name'] as String,
      email: m['email'] as String,
      age: m['age'] == null ? null : ((m['age'] as num).toInt()),
      role: m.containsKey('role')
          ? Role.values.byName(m['role'] as String)
          : Role.user,
      tags: m.containsKey('tags')
          ? <String>[
              for (Object? x0 in m['tags'] as List<dynamic>) x0 as String,
            ]
          : const <String>[],
    );
  }

  @override
  Map<String, dynamic> toMap(CreateUser o) {
    String f0 = o.name;
    String f1 = o.email;
    int? f2 = o.age;
    Role f3 = o.role;
    List<String> f4 = o.tags;
    return <String, dynamic>{
      'name': f0,
      'email': f1,
      'age': f2,
      'role': f3.name,
      'tags': f4,
    };
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'CreateUser',
      'properties': <String, dynamic>{
        'name': <String, dynamic>{
          'type': 'string',
          'minLength': 3,
          'maxLength': 50,
        },
        'email': <String, dynamic>{'type': 'string', 'format': 'email'},
        'age': <String, dynamic>{
          'type': <dynamic>['integer', 'null'],
          'minimum': 18,
        },
        'role': <String, dynamic>{
          'type': 'string',
          'enum': <dynamic>['admin', 'user'],
          'default': 'user',
        },
        'tags': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'type': 'string'},
          'maxItems': 5,
          'default': <dynamic>[],
        },
      },
      'required': <dynamic>['name', 'email'],
    };
  }
}

/// The checks, the converter and the JSON Schema of [TextRules].
const DtoSchema<TextRules> $TextRulesDto = _$TextRulesDto();

class _$TextRulesDto extends DtoSchema<TextRules> {
  const _$TextRulesDto();

  static const Map<String, String> _m = <String, String>{};

  static final RegExp _r0 = RegExp('^(?:[a-z]+)\$');

  @override
  Type get type => TextRules;

  @override
  String get name => 'TextRules';

  @override
  TextRules? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // len: String?
    Object? c0;
    c0 = s.string(s.read(input, 'len'), p, 'len', _m);
    // exact: String?
    Object? c1;
    c1 = s.string(s.read(input, 'exact'), p, 'exact', _m);
    // lenMin: String?
    Object? c2;
    c2 = s.string(s.read(input, 'len_min'), p, 'len_min', _m);
    // minLen: String?
    Object? c3;
    c3 = s.string(s.read(input, 'min_len'), p, 'min_len', _m);
    // maxLen: String?
    Object? c4;
    c4 = s.string(s.read(input, 'max_len'), p, 'max_len', _m);
    // email: String?
    Object? c5;
    c5 = s.string(s.read(input, 'email'), p, 'email', _m);
    // url: String?
    Object? c6;
    c6 = s.string(s.read(input, 'url'), p, 'url', _m);
    // uuid: String?
    Object? c7;
    c7 = s.string(s.read(input, 'uuid'), p, 'uuid', _m);
    // ip: String?
    Object? c8;
    c8 = s.string(s.read(input, 'ip'), p, 'ip', _m);
    // regex: String?
    Object? c9;
    c9 = s.string(s.read(input, 'regex'), p, 'regex', _m);
    // inList: String?
    Object? c10;
    c10 = s.string(s.read(input, 'in_list'), p, 'in_list', _m);
    // notIn: String?
    Object? c11;
    c11 = s.string(s.read(input, 'not_in'), p, 'not_in', _m);
    // starts: String?
    Object? c12;
    c12 = s.string(s.read(input, 'starts'), p, 'starts', _m);
    // ends: String?
    Object? c13;
    c13 = s.string(s.read(input, 'ends'), p, 'ends', _m);
    // alpha: String?
    Object? c14;
    c14 = s.string(s.read(input, 'alpha'), p, 'alpha', _m);
    // alnum: String?
    Object? c15;
    c15 = s.string(s.read(input, 'alnum'), p, 'alnum', _m);
    // dash: String?
    Object? c16;
    c16 = s.string(s.read(input, 'dash'), p, 'dash', _m);
    if (s.issues.length != e) return null;
    if (c0 is String) {
      if (!(c0.runes.length >= 2 && c0.runes.length <= 4)) {
        s.fail(
          p,
          'len',
          IssueCodes.lengthBetween,
          DefaultMessages.lengthBetween,
          c0,
          params: const <String, Object?>{'min': 2, 'max': 4},
          messages: _m,
        );
      }
    }
    if (c1 is String) {
      if (!(c1.runes.length == 3)) {
        s.fail(
          p,
          'exact',
          IssueCodes.length,
          DefaultMessages.length,
          c1,
          params: const <String, Object?>{'length': 3},
          messages: _m,
        );
      }
    }
    if (c2 is String) {
      if (!(c2.runes.length >= 2)) {
        s.fail(
          p,
          'len_min',
          IssueCodes.minLength,
          DefaultMessages.minLength,
          c2,
          params: const <String, Object?>{'min': 2},
          messages: _m,
        );
      }
    }
    if (c3 is String) {
      if (!(c3.runes.length >= 2)) {
        s.fail(
          p,
          'min_len',
          IssueCodes.minLength,
          DefaultMessages.minLength,
          c3,
          params: const <String, Object?>{'min': 2},
          messages: _m,
        );
      }
    }
    if (c4 is String) {
      if (!(c4.runes.length <= 3)) {
        s.fail(
          p,
          'max_len',
          IssueCodes.maxLength,
          DefaultMessages.maxLength,
          c4,
          params: const <String, Object?>{'max': 3},
          messages: _m,
        );
      }
    }
    if (c5 is String) {
      if (!(Patterns.email.hasMatch(c5))) {
        s.fail(
          p,
          'email',
          IssueCodes.email,
          DefaultMessages.email,
          c5,
          messages: _m,
        );
      }
    }
    if (c6 is String) {
      if (!(DtoChecks.url(c6))) {
        s.fail(p, 'url', IssueCodes.url, DefaultMessages.url, c6, messages: _m);
      }
    }
    if (c7 is String) {
      if (!(Patterns.uuid.hasMatch(c7))) {
        s.fail(
          p,
          'uuid',
          IssueCodes.uuid,
          DefaultMessages.uuid,
          c7,
          messages: _m,
        );
      }
    }
    if (c8 is String) {
      if (!(DtoChecks.ip(c8))) {
        s.fail(p, 'ip', IssueCodes.ip, DefaultMessages.ip, c8, messages: _m);
      }
    }
    if (c9 is String) {
      if (!(_r0.hasMatch(c9))) {
        s.fail(
          p,
          'regex',
          IssueCodes.regex,
          DefaultMessages.regex,
          c9,
          messages: _m,
        );
      }
    }
    if (c10 is String) {
      if (!(const <String>{'a', 'b'}.contains(c10))) {
        s.fail(
          p,
          'in_list',
          IssueCodes.inList,
          DefaultMessages.inList,
          c10,
          params: const <String, Object?>{'values': 'a, and b'},
          messages: _m,
        );
      }
    }
    if (c11 is String) {
      if (!(!const <String>{'root'}.contains(c11))) {
        s.fail(
          p,
          'not_in',
          IssueCodes.notIn,
          DefaultMessages.notIn,
          c11,
          messages: _m,
        );
      }
    }
    if (c12 is String) {
      if (!(c12.startsWith('dox'))) {
        s.fail(
          p,
          'starts',
          IssueCodes.startWith,
          DefaultMessages.startWith,
          c12,
          params: const <String, Object?>{'prefix': 'dox'},
          messages: _m,
        );
      }
    }
    if (c13 is String) {
      if (!(c13.endsWith('.dev'))) {
        s.fail(
          p,
          'ends',
          IssueCodes.endWith,
          DefaultMessages.endWith,
          c13,
          params: const <String, Object?>{'suffix': '.dev'},
          messages: _m,
        );
      }
    }
    if (c14 is String) {
      if (!(Patterns.alpha.hasMatch(c14))) {
        s.fail(
          p,
          'alpha',
          IssueCodes.alpha,
          DefaultMessages.alpha,
          c14,
          messages: _m,
        );
      }
    }
    if (c15 is String) {
      if (!(Patterns.alphaNumeric.hasMatch(c15))) {
        s.fail(
          p,
          'alnum',
          IssueCodes.alphaNumeric,
          DefaultMessages.alphaNumeric,
          c15,
          messages: _m,
        );
      }
    }
    if (c16 is String) {
      if (!(Patterns.alphaDash.hasMatch(c16))) {
        s.fail(
          p,
          'dash',
          IssueCodes.alphaDash,
          DefaultMessages.alphaDash,
          c16,
          messages: _m,
        );
      }
    }
    if (s.issues.length != e) return null;
    return TextRules(
      len: c0 is Undefined ? null : c0 as String?,
      exact: c1 is Undefined ? null : c1 as String?,
      lenMin: c2 is Undefined ? null : c2 as String?,
      minLen: c3 is Undefined ? null : c3 as String?,
      maxLen: c4 is Undefined ? null : c4 as String?,
      email: c5 is Undefined ? null : c5 as String?,
      url: c6 is Undefined ? null : c6 as String?,
      uuid: c7 is Undefined ? null : c7 as String?,
      ip: c8 is Undefined ? null : c8 as String?,
      regex: c9 is Undefined ? null : c9 as String?,
      inList: c10 is Undefined ? null : c10 as String?,
      notIn: c11 is Undefined ? null : c11 as String?,
      starts: c12 is Undefined ? null : c12 as String?,
      ends: c13 is Undefined ? null : c13 as String?,
      alpha: c14 is Undefined ? null : c14 as String?,
      alnum: c15 is Undefined ? null : c15 as String?,
      dash: c16 is Undefined ? null : c16 as String?,
    );
  }

  @override
  TextRules fromMap(Map<String, dynamic> m) {
    return TextRules(
      len: m['len'] == null ? null : (m['len'] as String),
      exact: m['exact'] == null ? null : (m['exact'] as String),
      lenMin: m['len_min'] == null ? null : (m['len_min'] as String),
      minLen: m['min_len'] == null ? null : (m['min_len'] as String),
      maxLen: m['max_len'] == null ? null : (m['max_len'] as String),
      email: m['email'] == null ? null : (m['email'] as String),
      url: m['url'] == null ? null : (m['url'] as String),
      uuid: m['uuid'] == null ? null : (m['uuid'] as String),
      ip: m['ip'] == null ? null : (m['ip'] as String),
      regex: m['regex'] == null ? null : (m['regex'] as String),
      inList: m['in_list'] == null ? null : (m['in_list'] as String),
      notIn: m['not_in'] == null ? null : (m['not_in'] as String),
      starts: m['starts'] == null ? null : (m['starts'] as String),
      ends: m['ends'] == null ? null : (m['ends'] as String),
      alpha: m['alpha'] == null ? null : (m['alpha'] as String),
      alnum: m['alnum'] == null ? null : (m['alnum'] as String),
      dash: m['dash'] == null ? null : (m['dash'] as String),
    );
  }

  @override
  Map<String, dynamic> toMap(TextRules o) {
    String? f0 = o.len;
    String? f1 = o.exact;
    String? f2 = o.lenMin;
    String? f3 = o.minLen;
    String? f4 = o.maxLen;
    String? f5 = o.email;
    String? f6 = o.url;
    String? f7 = o.uuid;
    String? f8 = o.ip;
    String? f9 = o.regex;
    String? f10 = o.inList;
    String? f11 = o.notIn;
    String? f12 = o.starts;
    String? f13 = o.ends;
    String? f14 = o.alpha;
    String? f15 = o.alnum;
    String? f16 = o.dash;
    return <String, dynamic>{
      'len': f0,
      'exact': f1,
      'len_min': f2,
      'min_len': f3,
      'max_len': f4,
      'email': f5,
      'url': f6,
      'uuid': f7,
      'ip': f8,
      'regex': f9,
      'in_list': f10,
      'not_in': f11,
      'starts': f12,
      'ends': f13,
      'alpha': f14,
      'alnum': f15,
      'dash': f16,
    };
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'TextRules',
      'properties': <String, dynamic>{
        'len': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'minLength': 2,
          'maxLength': 4,
        },
        'exact': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'minLength': 3,
          'maxLength': 3,
        },
        'len_min': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'minLength': 2,
        },
        'min_len': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'minLength': 2,
        },
        'max_len': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'maxLength': 3,
        },
        'email': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'format': 'email',
        },
        'url': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'format': 'uri',
        },
        'uuid': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'format': 'uuid',
        },
        'ip': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'anyOf': <dynamic>[
            <String, dynamic>{'format': 'ipv4'},
            <String, dynamic>{'format': 'ipv6'},
          ],
        },
        'regex': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'pattern': '^(?:[a-z]+)\$',
        },
        'in_list': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'enum': <dynamic>['a', 'b'],
        },
        'not_in': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'not': <String, dynamic>{
            'enum': <dynamic>['root'],
          },
        },
        'starts': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'pattern': '^dox',
        },
        'ends': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'pattern': '\\.dev\$',
        },
        'alpha': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'pattern': '^[a-zA-Z]+\$',
        },
        'alnum': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'pattern': '^[a-zA-Z0-9]+\$',
        },
        'dash': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'pattern': '^[a-zA-Z_-]+\$',
        },
      },
    };
  }
}

/// The checks, the converter and the JSON Schema of [ChangeText].
const DtoSchema<ChangeText> $ChangeTextDto = _$ChangeTextDto();

class _$ChangeTextDto extends DtoSchema<ChangeText> {
  const _$ChangeTextDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => ChangeText;

  @override
  String get name => 'ChangeText';

  @override
  ChangeText? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // trimmed: String?
    Object? c0;
    c0 = s.string(s.read(input, 'trimmed'), p, 'trimmed', _m, trim: true);
    // lower: String?
    Object? c1;
    c1 = s.string(
      s.read(input, 'lower'),
      p,
      'lower',
      _m,
      trim: true,
      textCase: 1,
    );
    // upper: String?
    Object? c2;
    c2 = s.string(s.read(input, 'upper'), p, 'upper', _m, textCase: 2);
    // keep: String?
    Object? c3;
    c3 = s.string(s.read(input, 'keep'), p, 'keep', _m, allowEmpty: true);
    // blank: String?
    Object? c4;
    c4 = s.string(s.read(input, 'blank'), p, 'blank', _m, trim: true);
    if (s.issues.length != e) return null;
    return ChangeText(
      trimmed: c0 is Undefined ? null : c0 as String?,
      lower: c1 is Undefined ? null : c1 as String?,
      upper: c2 is Undefined ? null : c2 as String?,
      keep: c3 is Undefined ? null : c3 as String?,
      blank: c4 is Undefined ? null : c4 as String?,
    );
  }

  @override
  ChangeText fromMap(Map<String, dynamic> m) {
    return ChangeText(
      trimmed: m['trimmed'] == null ? null : (m['trimmed'] as String),
      lower: m['lower'] == null ? null : (m['lower'] as String),
      upper: m['upper'] == null ? null : (m['upper'] as String),
      keep: m['keep'] == null ? null : (m['keep'] as String),
      blank: m['blank'] == null ? null : (m['blank'] as String),
    );
  }

  @override
  Map<String, dynamic> toMap(ChangeText o) {
    String? f0 = o.trimmed;
    String? f1 = o.lower;
    String? f2 = o.upper;
    String? f3 = o.keep;
    String? f4 = o.blank;
    return <String, dynamic>{
      'trimmed': f0,
      'lower': f1,
      'upper': f2,
      'keep': f3,
      'blank': f4,
    };
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'ChangeText',
      'properties': <String, dynamic>{
        'trimmed': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'lower': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'upper': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'keep': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'blank': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
      },
    };
  }
}

/// The checks, the converter and the JSON Schema of [NumberRules].
const DtoSchema<NumberRules> $NumberRulesDto = _$NumberRulesDto();

class _$NumberRulesDto extends DtoSchema<NumberRules> {
  const _$NumberRulesDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => NumberRules;

  @override
  String get name => 'NumberRules';

  @override
  NumberRules? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // min: int?
    Object? c0;
    c0 = s.integer(s.read(input, 'min'), p, 'min', _m);
    // max: int?
    Object? c1;
    c1 = s.integer(s.read(input, 'max'), p, 'max', _m);
    // range: num?
    Object? c2;
    c2 = s.number(s.read(input, 'range'), p, 'range', _m);
    // positive: int?
    Object? c3;
    c3 = s.integer(s.read(input, 'positive'), p, 'positive', _m);
    // gt: double?
    Object? c4;
    c4 = s.decimal(s.read(input, 'gt'), p, 'gt', _m);
    // lt: num?
    Object? c5;
    c5 = s.number(s.read(input, 'lt'), p, 'lt', _m);
    // inNum: int?
    Object? c6;
    c6 = s.integer(s.read(input, 'in_num'), p, 'in_num', _m);
    // notInNum: int?
    Object? c7;
    c7 = s.integer(s.read(input, 'not_in_num'), p, 'not_in_num', _m);
    if (s.issues.length != e) return null;
    if (c0 is int) {
      if (!(c0 >= 18)) {
        s.fail(
          p,
          'min',
          IssueCodes.min,
          DefaultMessages.min,
          c0,
          params: const <String, Object?>{'min': 18},
          messages: _m,
        );
      }
    }
    if (c1 is int) {
      if (!(c1 <= 100)) {
        s.fail(
          p,
          'max',
          IssueCodes.max,
          DefaultMessages.max,
          c1,
          params: const <String, Object?>{'max': 100},
          messages: _m,
        );
      }
    }
    if (c2 is num) {
      if (!(c2 >= 1 && c2 <= 10)) {
        s.fail(
          p,
          'range',
          IssueCodes.between,
          DefaultMessages.between,
          c2,
          params: const <String, Object?>{'min': 1, 'max': 10},
          messages: _m,
        );
      }
    }
    if (c3 is int) {
      if (!(c3 > 0)) {
        s.fail(
          p,
          'positive',
          IssueCodes.greaterThan,
          DefaultMessages.greaterThan,
          c3,
          params: const <String, Object?>{'min': 0},
          messages: _m,
        );
      }
    }
    if (c4 is double) {
      if (!(c4 > 0.5)) {
        s.fail(
          p,
          'gt',
          IssueCodes.greaterThan,
          DefaultMessages.greaterThan,
          c4,
          params: const <String, Object?>{'min': 0.5},
          messages: _m,
        );
      }
    }
    if (c5 is num) {
      if (!(c5 < 100)) {
        s.fail(
          p,
          'lt',
          IssueCodes.lessThan,
          DefaultMessages.lessThan,
          c5,
          params: const <String, Object?>{'max': 100},
          messages: _m,
        );
      }
    }
    if (c6 is int) {
      if (!(const <num>{1, 2, 3}.contains(c6))) {
        s.fail(
          p,
          'in_num',
          IssueCodes.inList,
          DefaultMessages.inList,
          c6,
          params: const <String, Object?>{'values': '1, 2, and 3'},
          messages: _m,
        );
      }
    }
    if (c7 is int) {
      if (!(!const <num>{0}.contains(c7))) {
        s.fail(
          p,
          'not_in_num',
          IssueCodes.notIn,
          DefaultMessages.notIn,
          c7,
          messages: _m,
        );
      }
    }
    if (s.issues.length != e) return null;
    return NumberRules(
      min: c0 is Undefined ? null : c0 as int?,
      max: c1 is Undefined ? null : c1 as int?,
      range: c2 is Undefined ? null : c2 as num?,
      positive: c3 is Undefined ? null : c3 as int?,
      gt: c4 is Undefined ? null : c4 as double?,
      lt: c5 is Undefined ? null : c5 as num?,
      inNum: c6 is Undefined ? null : c6 as int?,
      notInNum: c7 is Undefined ? null : c7 as int?,
    );
  }

  @override
  NumberRules fromMap(Map<String, dynamic> m) {
    return NumberRules(
      min: m['min'] == null ? null : ((m['min'] as num).toInt()),
      max: m['max'] == null ? null : ((m['max'] as num).toInt()),
      range: m['range'] == null ? null : (m['range'] as num),
      positive: m['positive'] == null ? null : ((m['positive'] as num).toInt()),
      gt: m['gt'] == null ? null : ((m['gt'] as num).toDouble()),
      lt: m['lt'] == null ? null : (m['lt'] as num),
      inNum: m['in_num'] == null ? null : ((m['in_num'] as num).toInt()),
      notInNum: m['not_in_num'] == null
          ? null
          : ((m['not_in_num'] as num).toInt()),
    );
  }

  @override
  Map<String, dynamic> toMap(NumberRules o) {
    int? f0 = o.min;
    int? f1 = o.max;
    num? f2 = o.range;
    int? f3 = o.positive;
    double? f4 = o.gt;
    num? f5 = o.lt;
    int? f6 = o.inNum;
    int? f7 = o.notInNum;
    return <String, dynamic>{
      'min': f0,
      'max': f1,
      'range': f2,
      'positive': f3,
      'gt': f4,
      'lt': f5,
      'in_num': f6,
      'not_in_num': f7,
    };
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'NumberRules',
      'properties': <String, dynamic>{
        'min': <String, dynamic>{
          'type': <dynamic>['integer', 'null'],
          'minimum': 18,
        },
        'max': <String, dynamic>{
          'type': <dynamic>['integer', 'null'],
          'maximum': 100,
        },
        'range': <String, dynamic>{
          'type': <dynamic>['number', 'null'],
          'minimum': 1,
          'maximum': 10,
        },
        'positive': <String, dynamic>{
          'type': <dynamic>['integer', 'null'],
          'exclusiveMinimum': 0,
        },
        'gt': <String, dynamic>{
          'type': <dynamic>['number', 'null'],
          'exclusiveMinimum': 0.5,
        },
        'lt': <String, dynamic>{
          'type': <dynamic>['number', 'null'],
          'exclusiveMaximum': 100,
        },
        'in_num': <String, dynamic>{
          'type': <dynamic>['integer', 'null'],
          'enum': <dynamic>[1, 2, 3],
        },
        'not_in_num': <String, dynamic>{
          'type': <dynamic>['integer', 'null'],
          'not': <String, dynamic>{
            'enum': <dynamic>[0],
          },
        },
      },
    };
  }
}

/// The checks, the converter and the JSON Schema of [ListRules].
const DtoSchema<ListRules> $ListRulesDto = _$ListRulesDto();

class _$ListRulesDto extends DtoSchema<ListRules> {
  const _$ListRulesDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => ListRules;

  @override
  String get name => 'ListRules';

  @override
  ListRules? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // minItems: List<int>?
    Object? c0;
    c0 = s.list(s.read(input, 'min_items'), p, 'min_items', _m);
    if (c0 is List) {
      List<Object> q0 = <Object>[...p, 'min_items'];
      List<int> o0 = <int>[];
      for (int i0 = 0; i0 < c0.length; i0++) {
        Object? x0;
        x0 = s.integer(c0[i0], q0, i0, _m);
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as int);
        }
      }
      c0 = o0;
    }
    // maxItems: List<String>?
    Object? c1;
    c1 = s.list(s.read(input, 'max_items'), p, 'max_items', _m);
    if (c1 is List) {
      List<Object> q0 = <Object>[...p, 'max_items'];
      List<String> o0 = <String>[];
      for (int i0 = 0; i0 < c1.length; i0++) {
        Object? x0;
        x0 = s.string(c1[i0], q0, i0, _m);
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as String);
        }
      }
      c1 = o0;
    }
    // unique: List<String>?
    Object? c2;
    c2 = s.list(s.read(input, 'unique'), p, 'unique', _m);
    if (c2 is List) {
      List<Object> q0 = <Object>[...p, 'unique'];
      List<String> o0 = <String>[];
      for (int i0 = 0; i0 < c2.length; i0++) {
        Object? x0;
        x0 = s.string(c2[i0], q0, i0, _m);
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as String);
        }
      }
      c2 = o0;
    }
    // emails: List<String>?
    Object? c3;
    c3 = s.list(s.read(input, 'emails'), p, 'emails', _m);
    if (c3 is List) {
      List<Object> q0 = <Object>[...p, 'emails'];
      List<String> o0 = <String>[];
      for (int i0 = 0; i0 < c3.length; i0++) {
        Object? x0;
        x0 = s.string(c3[i0], q0, i0, _m);
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as String);
        }
      }
      c3 = o0;
    }
    if (s.issues.length != e) return null;
    if (c0 is List<int>) {
      if (!(c0.length >= 1)) {
        s.fail(
          p,
          'min_items',
          IssueCodes.minItems,
          DefaultMessages.minItems,
          c0,
          params: const <String, Object?>{'min': 1},
          messages: _m,
        );
      }
    }
    if (c1 is List<String>) {
      if (!(c1.length <= 2)) {
        s.fail(
          p,
          'max_items',
          IssueCodes.maxItems,
          DefaultMessages.maxItems,
          c1,
          params: const <String, Object?>{'max': 2},
          messages: _m,
        );
      }
    }
    if (c2 is List<String>) {
      if (!(!DtoChecks.hasDuplicates(c2))) {
        s.fail(
          p,
          'unique',
          IssueCodes.uniqueItems,
          DefaultMessages.uniqueItems,
          c2,
          messages: _m,
        );
      }
    }
    if (c3 is List<String>) {
      List<Object> q = <Object>[...p, 'emails'];
      for (int i = 0; i < c3.length; i++) {
        String v = c3[i];
        if (!(Patterns.email.hasMatch(v))) {
          s.fail(
            q,
            i,
            IssueCodes.email,
            DefaultMessages.email,
            v,
            messages: _m,
          );
        }
      }
    }
    if (s.issues.length != e) return null;
    return ListRules(
      minItems: c0 is Undefined ? null : c0 as List<int>?,
      maxItems: c1 is Undefined ? null : c1 as List<String>?,
      unique: c2 is Undefined ? null : c2 as List<String>?,
      emails: c3 is Undefined ? null : c3 as List<String>?,
    );
  }

  @override
  ListRules fromMap(Map<String, dynamic> m) {
    return ListRules(
      minItems: m['min_items'] == null
          ? null
          : (<int>[
              for (Object? x0 in m['min_items'] as List<dynamic>)
                (x0 as num).toInt(),
            ]),
      maxItems: m['max_items'] == null
          ? null
          : (<String>[
              for (Object? x0 in m['max_items'] as List<dynamic>) x0 as String,
            ]),
      unique: m['unique'] == null
          ? null
          : (<String>[
              for (Object? x0 in m['unique'] as List<dynamic>) x0 as String,
            ]),
      emails: m['emails'] == null
          ? null
          : (<String>[
              for (Object? x0 in m['emails'] as List<dynamic>) x0 as String,
            ]),
    );
  }

  @override
  Map<String, dynamic> toMap(ListRules o) {
    List<int>? f0 = o.minItems;
    List<String>? f1 = o.maxItems;
    List<String>? f2 = o.unique;
    List<String>? f3 = o.emails;
    return <String, dynamic>{
      'min_items': f0,
      'max_items': f1,
      'unique': f2,
      'emails': f3,
    };
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'ListRules',
      'properties': <String, dynamic>{
        'min_items': <String, dynamic>{
          'type': <dynamic>['array', 'null'],
          'items': <String, dynamic>{'type': 'integer'},
          'minItems': 1,
        },
        'max_items': <String, dynamic>{
          'type': <dynamic>['array', 'null'],
          'items': <String, dynamic>{'type': 'string'},
          'maxItems': 2,
        },
        'unique': <String, dynamic>{
          'type': <dynamic>['array', 'null'],
          'items': <String, dynamic>{'type': 'string'},
          'uniqueItems': true,
        },
        'emails': <String, dynamic>{
          'type': <dynamic>['array', 'null'],
          'items': <String, dynamic>{'type': 'string', 'format': 'email'},
        },
      },
    };
  }
}

/// The checks, the converter and the JSON Schema of [DateRules].
const DtoSchema<DateRules> $DateRulesDto = _$DateRulesDto();

class _$DateRulesDto extends DtoSchema<DateRules> {
  const _$DateRulesDto();

  static const Map<String, String> _m = <String, String>{};

  static final DateTime _d0 = DateTime.fromMicrosecondsSinceEpoch(
    946684800000000,
    isUtc: true,
  );

  @override
  Type get type => DateRules;

  @override
  String get name => 'DateRules';

  @override
  DateRules? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // after: DateTime?
    Object? c0;
    c0 = s.date(s.read(input, 'after'), p, 'after', _m);
    // before: DateTime?
    Object? c1;
    c1 = s.date(s.read(input, 'before'), p, 'before', _m);
    if (s.issues.length != e) return null;
    if (c0 is DateTime) {
      if (!(c0.isAfter(_d0))) {
        s.fail(
          p,
          'after',
          IssueCodes.after,
          DefaultMessages.after,
          c0,
          params: const <String, Object?>{'date': '2000-01-01'},
          messages: _m,
        );
      }
    }
    if (c1 is DateTime) {
      if (!(c1.isBefore(s.now))) {
        s.fail(
          p,
          'before',
          IssueCodes.before,
          DefaultMessages.before,
          c1,
          params: const <String, Object?>{'date': 'now'},
          messages: _m,
        );
      }
    }
    if (s.issues.length != e) return null;
    return DateRules(
      after: c0 is Undefined ? null : c0 as DateTime?,
      before: c1 is Undefined ? null : c1 as DateTime?,
    );
  }

  @override
  DateRules fromMap(Map<String, dynamic> m) {
    return DateRules(
      after: m['after'] == null
          ? null
          : (DateTime.parse(m['after'] as String).toUtc()),
      before: m['before'] == null
          ? null
          : (DateTime.parse(m['before'] as String).toUtc()),
    );
  }

  @override
  Map<String, dynamic> toMap(DateRules o) {
    DateTime? f0 = o.after;
    DateTime? f1 = o.before;
    return <String, dynamic>{
      'after': f0 == null ? null : f0.toIso8601String(),
      'before': f1 == null ? null : f1.toIso8601String(),
    };
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'DateRules',
      'properties': <String, dynamic>{
        'after': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'format': 'date-time',
        },
        'before': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'format': 'date-time',
        },
      },
    };
  }
}

/// The checks, the converter and the JSON Schema of [AllTypes].
const DtoSchema<AllTypes> $AllTypesDto = _$AllTypesDto();

class _$AllTypesDto extends DtoSchema<AllTypes> {
  const _$AllTypesDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => AllTypes;

  @override
  String get name => 'AllTypes';

  @override
  AllTypes? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // s: String?
    Object? c0;
    c0 = s.string(s.read(input, 's'), p, 's', _m);
    // i: int?
    Object? c1;
    c1 = s.integer(s.read(input, 'i'), p, 'i', _m);
    // d: double?
    Object? c2;
    c2 = s.decimal(s.read(input, 'd'), p, 'd', _m);
    // n: num?
    Object? c3;
    c3 = s.number(s.read(input, 'n'), p, 'n', _m);
    // b: bool?
    Object? c4;
    c4 = s.boolean(s.read(input, 'b'), p, 'b', _m);
    // dt: DateTime?
    Object? c5;
    c5 = s.date(s.read(input, 'dt'), p, 'dt', _m);
    // role: Role?
    Object? c6;
    c6 = s.enumName(s.read(input, 'role'), p, 'role', _m, const <String>[
      'admin',
      'user',
    ]);
    if (c6 is String) {
      c6 = switch (c6) {
        'admin' => Role.admin,
        _ => Role.user,
      };
    }
    // list: List<int>?
    Object? c7;
    c7 = s.list(s.read(input, 'list'), p, 'list', _m);
    if (c7 is List) {
      List<Object> q0 = <Object>[...p, 'list'];
      List<int> o0 = <int>[];
      for (int i0 = 0; i0 < c7.length; i0++) {
        Object? x0;
        x0 = s.integer(c7[i0], q0, i0, _m);
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as int);
        }
      }
      c7 = o0;
    }
    // map: Map<String, int>?
    Object? c8;
    c8 = s.object(s.read(input, 'map'), p, 'map', _m);
    if (c8 is Map) {
      List<Object> q0 = <Object>[...p, 'map'];
      Map<String, int> o0 = <String, int>{};
      for (MapEntry<dynamic, dynamic> n0 in c8.entries) {
        String k0 = '${n0.key}';
        Object? x0;
        x0 = s.integer(n0.value, q0, k0, _m);
        if (x0 == null || x0 is Undefined) {
          s.required(q0, k0, _m);
        } else if (x0 is! Invalid) {
          o0[k0] = x0 as int;
        }
      }
      c8 = o0;
    }
    // any: Object?
    Object? c9;
    c9 = s.read(input, 'any');
    // raw: Map<String, dynamic>?
    Object? c10;
    c10 = s.object(s.read(input, 'raw'), p, 'raw', _m);
    if (s.issues.length != e) return null;
    return AllTypes(
      s: c0 is Undefined ? null : c0 as String?,
      i: c1 is Undefined ? null : c1 as int?,
      d: c2 is Undefined ? null : c2 as double?,
      n: c3 is Undefined ? null : c3 as num?,
      b: c4 is Undefined ? null : c4 as bool?,
      dt: c5 is Undefined ? null : c5 as DateTime?,
      role: c6 is Undefined ? null : c6 as Role?,
      list: c7 is Undefined ? null : c7 as List<int>?,
      map: c8 is Undefined ? null : c8 as Map<String, int>?,
      any: c9 is Undefined ? null : c9,
      raw: c10 is Undefined ? null : c10 as Map<String, dynamic>?,
    );
  }

  @override
  AllTypes fromMap(Map<String, dynamic> m) {
    return AllTypes(
      s: m['s'] == null ? null : (m['s'] as String),
      i: m['i'] == null ? null : ((m['i'] as num).toInt()),
      d: m['d'] == null ? null : ((m['d'] as num).toDouble()),
      n: m['n'] == null ? null : (m['n'] as num),
      b: m['b'] == null ? null : (m['b'] as bool),
      dt: m['dt'] == null ? null : (DateTime.parse(m['dt'] as String).toUtc()),
      role: m['role'] == null
          ? null
          : (Role.values.byName(m['role'] as String)),
      list: m['list'] == null
          ? null
          : (<int>[
              for (Object? x0 in m['list'] as List<dynamic>)
                (x0 as num).toInt(),
            ]),
      map: m['map'] == null
          ? null
          : (<String, int>{
              for (MapEntry<dynamic, dynamic> x0
                  in (m['map'] as Map<dynamic, dynamic>).entries)
                x0.key as String: (x0.value as num).toInt(),
            }),
      any: m['any'],
      raw: m['raw'] == null ? null : (m['raw'] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toMap(AllTypes o) {
    String? f0 = o.s;
    int? f1 = o.i;
    double? f2 = o.d;
    num? f3 = o.n;
    bool? f4 = o.b;
    DateTime? f5 = o.dt;
    Role? f6 = o.role;
    List<int>? f7 = o.list;
    Map<String, int>? f8 = o.map;
    Object? f9 = o.any;
    Map<String, dynamic>? f10 = o.raw;
    return <String, dynamic>{
      's': f0,
      'i': f1,
      'd': f2,
      'n': f3,
      'b': f4,
      'dt': f5 == null ? null : f5.toIso8601String(),
      'role': f6 == null ? null : f6.name,
      'list': f7,
      'map': f8,
      'any': f9,
      'raw': f10,
    };
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'AllTypes',
      'properties': <String, dynamic>{
        's': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'i': <String, dynamic>{
          'type': <dynamic>['integer', 'null'],
        },
        'd': <String, dynamic>{
          'type': <dynamic>['number', 'null'],
        },
        'n': <String, dynamic>{
          'type': <dynamic>['number', 'null'],
        },
        'b': <String, dynamic>{
          'type': <dynamic>['boolean', 'null'],
        },
        'dt': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'format': 'date-time',
        },
        'role': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'enum': <dynamic>['admin', 'user'],
        },
        'list': <String, dynamic>{
          'type': <dynamic>['array', 'null'],
          'items': <String, dynamic>{'type': 'integer'},
        },
        'map': <String, dynamic>{
          'type': <dynamic>['object', 'null'],
          'additionalProperties': <String, dynamic>{'type': 'integer'},
        },
        'any': <String, dynamic>{
          'anyOf': <dynamic>[
            <String, dynamic>{},
            <String, dynamic>{'type': 'null'},
          ],
        },
        'raw': <String, dynamic>{
          'type': <dynamic>['object', 'null'],
        },
      },
    };
  }
}

/// The checks, the converter and the JSON Schema of [SearchUsers].
const DtoSchema<SearchUsers> $SearchUsersDto = _$SearchUsersDto();

class _$SearchUsersDto extends DtoSchema<SearchUsers> {
  const _$SearchUsersDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => SearchUsers;

  @override
  String get name => 'SearchUsers';

  @override
  Source get source => Source.query;

  @override
  SearchUsers? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // q: String?
    Object? c0;
    c0 = s.string(s.read(input, 'q'), p, 'q', _m);
    // page: int
    Object? c1;
    c1 = s.integer(s.read(input, 'page'), p, 'page', _m);
    if (c1 == null) s.required(p, 'page', _m);
    // tags: List<String>
    Object? c2;
    c2 = s.list(s.read(input, 'tags'), p, 'tags', _m);
    if (c2 is List) {
      List<Object> q0 = <Object>[...p, 'tags'];
      List<String> o0 = <String>[];
      for (int i0 = 0; i0 < c2.length; i0++) {
        Object? x0;
        x0 = s.string(c2[i0], q0, i0, _m);
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as String);
        }
      }
      c2 = o0;
    }
    if (c2 == null) s.required(p, 'tags', _m);
    if (s.issues.length != e) return null;
    return SearchUsers(
      q: c0 is Undefined ? null : c0 as String?,
      page: c1 is Undefined ? 1 : c1 as int,
      tags: c2 is Undefined ? const <String>[] : c2 as List<String>,
    );
  }

  @override
  SearchUsers fromMap(Map<String, dynamic> m) {
    return SearchUsers(
      q: m['q'] == null ? null : (m['q'] as String),
      page: m.containsKey('page') ? (m['page'] as num).toInt() : 1,
      tags: m.containsKey('tags')
          ? <String>[
              for (Object? x0 in m['tags'] as List<dynamic>) x0 as String,
            ]
          : const <String>[],
    );
  }

  @override
  Map<String, dynamic> toMap(SearchUsers o) {
    String? f0 = o.q;
    int f1 = o.page;
    List<String> f2 = o.tags;
    return <String, dynamic>{'q': f0, 'page': f1, 'tags': f2};
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'SearchUsers',
      'properties': <String, dynamic>{
        'q': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'page': <String, dynamic>{'type': 'integer', 'default': 1},
        'tags': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'type': 'string'},
          'default': <dynamic>[],
        },
      },
    };
  }
}

/// The checks, the converter and the JSON Schema of [StrictInput].
const DtoSchema<StrictInput> $StrictInputDto = _$StrictInputDto();

class _$StrictInputDto extends DtoSchema<StrictInput> {
  const _$StrictInputDto();

  static const Map<String, String> _m = <String, String>{};

  static const Set<String> _keys = <String>{'name'};

  @override
  Type get type => StrictInput;

  @override
  String get name => 'StrictInput';

  @override
  StrictInput? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    for (Object? k in input.keys) {
      if (!_keys.contains(k)) {
        s.fail(
          p,
          '$k',
          IssueCodes.unrecognizedKeys,
          DefaultMessages.notAllowed,
          input[k],
          messages: _m,
        );
      }
    }
    // name: String
    Object? c0;
    c0 = s.string(s.read(input, 'name'), p, 'name', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'name', _m);
    if (s.issues.length != e) return null;
    return StrictInput(name: c0 as String);
  }

  @override
  StrictInput fromMap(Map<String, dynamic> m) {
    return StrictInput(name: m['name'] as String);
  }

  @override
  Map<String, dynamic> toMap(StrictInput o) {
    String f0 = o.name;
    return <String, dynamic>{'name': f0};
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'StrictInput',
      'properties': <String, dynamic>{
        'name': <String, dynamic>{'type': 'string'},
      },
      'required': <dynamic>['name'],
      'additionalProperties': false,
    };
  }
}

/// The checks, the converter and the JSON Schema of [WithMessages].
const DtoSchema<WithMessages> $WithMessagesDto = _$WithMessagesDto();

class _$WithMessagesDto extends DtoSchema<WithMessages> {
  const _$WithMessagesDto();

  static const Map<String, String> _m = <String, String>{
    'email.required': 'We need your email',
    'required': 'Please fill in {field}',
    'integer': 'The {field} must be a number',
  };

  @override
  Type get type => WithMessages;

  @override
  String get name => 'WithMessages';

  @override
  WithMessages? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // email: String
    Object? c0;
    c0 = s.string(s.read(input, 'email'), p, 'email', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'email', _m);
    // name: String
    Object? c1;
    c1 = s.string(s.read(input, 'name'), p, 'name', _m);
    if (c1 == null || c1 is Undefined) s.required(p, 'name', _m);
    // age: int?
    Object? c2;
    c2 = s.integer(s.read(input, 'age'), p, 'age', _m);
    // nick: String?
    Object? c3;
    c3 = s.string(s.read(input, 'nick'), p, 'nick', _m);
    if (s.issues.length != e) return null;
    if (c3 is String) {
      if (!(c3.runes.length >= 3)) {
        s.fail(
          p,
          'nick',
          IssueCodes.minLength,
          DefaultMessages.minLength,
          c3,
          params: const <String, Object?>{'min': 3},
          message: 'At least {min} letters, please',
          messages: _m,
        );
      }
    }
    if (s.issues.length != e) return null;
    return WithMessages(
      email: c0 as String,
      name: c1 as String,
      age: c2 is Undefined ? null : c2 as int?,
      nick: c3 is Undefined ? null : c3 as String?,
    );
  }

  @override
  WithMessages fromMap(Map<String, dynamic> m) {
    return WithMessages(
      email: m['email'] as String,
      name: m['name'] as String,
      age: m['age'] == null ? null : ((m['age'] as num).toInt()),
      nick: m['nick'] == null ? null : (m['nick'] as String),
    );
  }

  @override
  Map<String, dynamic> toMap(WithMessages o) {
    String f0 = o.email;
    String f1 = o.name;
    int? f2 = o.age;
    String? f3 = o.nick;
    return <String, dynamic>{'email': f0, 'name': f1, 'age': f2, 'nick': f3};
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'WithMessages',
      'properties': <String, dynamic>{
        'email': <String, dynamic>{'type': 'string'},
        'name': <String, dynamic>{'type': 'string'},
        'age': <String, dynamic>{
          'type': <dynamic>['integer', 'null'],
        },
        'nick': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'minLength': 3,
        },
      },
      'required': <dynamic>['email', 'name'],
    };
  }
}

/// The checks, the converter and the JSON Schema of [SignUpKeys].
const DtoSchema<SignUpKeys> $SignUpKeysDto = _$SignUpKeysDto();

class _$SignUpKeysDto extends DtoSchema<SignUpKeys> {
  const _$SignUpKeysDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => SignUpKeys;

  @override
  String get name => 'SignUpKeys';

  @override
  SignUpKeys? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // firstName: String
    Object? c0;
    c0 = s.string(s.read(input, 'first_name'), p, 'first_name', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'first_name', _m);
    // email: String
    Object? c1;
    c1 = s.string(s.read(input, 'emailAddress'), p, 'emailAddress', _m);
    if (c1 == null || c1 is Undefined) s.required(p, 'emailAddress', _m);
    if (s.issues.length != e) return null;
    return SignUpKeys(firstName: c0 as String, email: c1 as String);
  }

  @override
  SignUpKeys fromMap(Map<String, dynamic> m) {
    return SignUpKeys(
      firstName: m['first_name'] as String,
      email: m['emailAddress'] as String,
    );
  }

  @override
  Map<String, dynamic> toMap(SignUpKeys o) {
    String f0 = o.firstName;
    String f1 = o.email;
    return <String, dynamic>{'first_name': f0, 'emailAddress': f1};
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'SignUpKeys',
      'properties': <String, dynamic>{
        'first_name': <String, dynamic>{'type': 'string'},
        'emailAddress': <String, dynamic>{'type': 'string'},
      },
      'required': <dynamic>['first_name', 'emailAddress'],
    };
  }
}

/// The checks, the converter and the JSON Schema of [CamelKeys].
const DtoSchema<CamelKeys> $CamelKeysDto = _$CamelKeysDto();

class _$CamelKeysDto extends DtoSchema<CamelKeys> {
  const _$CamelKeysDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => CamelKeys;

  @override
  String get name => 'CamelKeys';

  @override
  CamelKeys? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // firstName: String
    Object? c0;
    c0 = s.string(s.read(input, 'firstName'), p, 'firstName', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'firstName', _m);
    if (s.issues.length != e) return null;
    return CamelKeys(firstName: c0 as String);
  }

  @override
  CamelKeys fromMap(Map<String, dynamic> m) {
    return CamelKeys(firstName: m['firstName'] as String);
  }

  @override
  Map<String, dynamic> toMap(CamelKeys o) {
    String f0 = o.firstName;
    return <String, dynamic>{'firstName': f0};
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'CamelKeys',
      'properties': <String, dynamic>{
        'firstName': <String, dynamic>{'type': 'string'},
      },
      'required': <dynamic>['firstName'],
    };
  }
}

/// The checks, the converter and the JSON Schema of [UpdateUser].
const DtoSchema<UpdateUser> $UpdateUserDto = _$UpdateUserDto();

class _$UpdateUserDto extends DtoSchema<UpdateUser> {
  const _$UpdateUserDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => UpdateUser;

  @override
  String get name => 'UpdateUser';

  @override
  UpdateUser? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // bio: Maybe<String?>
    Object? c0;
    c0 = s.string(s.read(input, 'bio'), p, 'bio', _m);
    // age: Maybe<int>
    Object? c1;
    c1 = s.integer(s.read(input, 'age'), p, 'age', _m);
    if (c1 == null) s.required(p, 'age', _m);
    if (s.issues.length != e) return null;
    if (c0 is String) {
      if (!(c0.runes.length <= 5)) {
        s.fail(
          p,
          'bio',
          IssueCodes.maxLength,
          DefaultMessages.maxLength,
          c0,
          params: const <String, Object?>{'max': 5},
          messages: _m,
        );
      }
    }
    if (s.issues.length != e) return null;
    return UpdateUser(
      bio: c0 is Undefined
          ? const Maybe<String?>.missing()
          : Maybe<String?>(c0 as String?),
      age: c1 is Undefined ? const Maybe<int>.missing() : Maybe<int>(c1 as int),
    );
  }

  @override
  UpdateUser fromMap(Map<String, dynamic> m) {
    return UpdateUser(
      bio: m.containsKey('bio')
          ? Maybe<String?>(m['bio'] == null ? null : (m['bio'] as String))
          : const Maybe<String?>.missing(),
      age: m.containsKey('age')
          ? Maybe<int>((m['age'] as num).toInt())
          : const Maybe<int>.missing(),
    );
  }

  @override
  Map<String, dynamic> toMap(UpdateUser o) {
    Maybe<String?> f0 = o.bio;
    Maybe<int> f1 = o.age;
    return <String, dynamic>{
      if (f0 case Maybe<String?>(isPresent: true, value: String? g0)) 'bio': g0,
      if (f1 case Maybe<int>(isPresent: true, value: int g1)) 'age': g1,
    };
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'UpdateUser',
      'properties': <String, dynamic>{
        'bio': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'maxLength': 5,
        },
        'age': <String, dynamic>{'type': 'integer'},
      },
    };
  }
}
