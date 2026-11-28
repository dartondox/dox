// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rules.dto.dart';

// **************************************************************************
// DoxDtoGenerator
// **************************************************************************

// ignore_for_file: type=lint

/// The checks, the converter and the JSON Schema of [CreateUser].
const DtoSchema<CreateUser> $CreateUserDto = _$CreateUserDto();

class _$CreateUserDto extends DtoSchema<CreateUser>
    implements JsonObjectWriter {
  const _$CreateUserDto();

  static const Map<String, String> _messages = <String, String>{};

  @override
  Type get type => CreateUser;

  @override
  String get name => 'CreateUser';

  @override
  bool get usesRequiredWhen => false;

  @override
  CreateUser? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // name: String
    Object? name = state.string(
      state.read(input, 'name'),
      path,
      'name',
      _messages,
      trim: true,
    );
    if (name == null || name is Undefined)
      state.required(path, 'name', _messages);
    // email: String
    Object? email = state.string(
      state.read(input, 'email'),
      path,
      'email',
      _messages,
    );
    if (email == null || email is Undefined)
      state.required(path, 'email', _messages);
    // age: int?
    Object? age = state.integer(
      state.read(input, 'age'),
      path,
      'age',
      _messages,
    );
    // role: Role
    Object? role = state.enumName(
      state.read(input, 'role'),
      path,
      'role',
      _messages,
      const <String>['admin', 'user'],
    );
    if (role is String) {
      role = switch (role) {
        'admin' => Role.admin,
        _ => Role.user,
      };
    }
    if (role == null) state.required(path, 'role', _messages);
    // tags: List<String>
    Object? tags = state.list(
      state.read(input, 'tags'),
      path,
      'tags',
      _messages,
    );
    if (tags is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'tags'];
      List<String> o0 = <String>[];
      for (int i0 = 0; i0 < tags.length; i0++) {
        Object? x0 = state.string(tags[i0], q0, i0, _messages);
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as String);
        }
      }
      tags = state.issues.length != b0 ? invalid : o0;
    }
    if (tags == null) state.required(path, 'tags', _messages);
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (name is String) {
      if (!(name.runes.length >= 3 && name.runes.length <= 50)) {
        state.fail(
          path,
          'name',
          IssueCodes.lengthBetween,
          DefaultMessages.lengthBetween,
          name,
          params: const <String, Object?>{'min': 3, 'max': 50},
          messages: _messages,
        );
      }
    }
    if (email is String) {
      if (!(Patterns.email.hasMatch(email))) {
        state.fail(
          path,
          'email',
          IssueCodes.email,
          DefaultMessages.email,
          email,
          messages: _messages,
        );
      }
    }
    if (age is int) {
      if (!(age >= 18)) {
        state.fail(
          path,
          'age',
          IssueCodes.min,
          DefaultMessages.min,
          age,
          params: const <String, Object?>{'min': 18},
          messages: _messages,
        );
      }
    }
    if (tags is List<String>) {
      if (!(tags.length <= 5)) {
        state.fail(
          path,
          'tags',
          IssueCodes.maxItems,
          DefaultMessages.maxItems,
          tags,
          params: const <String, Object?>{'max': 5},
          messages: _messages,
        );
      }
    }
    if (state.issues.length != issuesBefore) return null;
    return CreateUser(
      name: name as String,
      email: email as String,
      age: age is Undefined ? null : age as int?,
      role: role is Undefined ? Role.user : role as Role,
      tags: tags is Undefined ? const <String>[] : tags as List<String>,
    );
  }

  @override
  CreateUser fromMap(Map<String, dynamic> map) {
    return CreateUser(
      name: map['name'] as String,
      email: map['email'] as String,
      age: map['age'] == null ? null : ((map['age'] as num).toInt()),
      role: map.containsKey('role')
          ? Role.values.byName(map['role'] as String)
          : Role.user,
      tags: map.containsKey('tags')
          ? <String>[
              for (Object? x0 in map['tags'] as List<dynamic>) x0 as String,
            ]
          : const <String>[],
    );
  }

  @override
  Map<String, dynamic> toMap(CreateUser dto) {
    return <String, dynamic>{
      'name': dto.name,
      'email': dto.email,
      'age': dto.age,
      'role': dto.role.name,
      'tags': dto.tags,
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as CreateUser));

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

class _$TextRulesDto extends DtoSchema<TextRules> implements JsonObjectWriter {
  const _$TextRulesDto();

  static const Map<String, String> _messages = <String, String>{};

  static final RegExp _r0 = RegExp('^(?:[a-z]+)\$');

  @override
  Type get type => TextRules;

  @override
  String get name => 'TextRules';

  @override
  bool get usesRequiredWhen => false;

  @override
  TextRules? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // len: String?
    Object? len = state.string(
      state.read(input, 'len'),
      path,
      'len',
      _messages,
    );
    // exact: String?
    Object? exact = state.string(
      state.read(input, 'exact'),
      path,
      'exact',
      _messages,
    );
    // lenMin: String?
    Object? lenMin = state.string(
      state.read(input, 'len_min'),
      path,
      'len_min',
      _messages,
    );
    // minLen: String?
    Object? minLen = state.string(
      state.read(input, 'min_len'),
      path,
      'min_len',
      _messages,
    );
    // maxLen: String?
    Object? maxLen = state.string(
      state.read(input, 'max_len'),
      path,
      'max_len',
      _messages,
    );
    // email: String?
    Object? email = state.string(
      state.read(input, 'email'),
      path,
      'email',
      _messages,
    );
    // url: String?
    Object? url = state.string(
      state.read(input, 'url'),
      path,
      'url',
      _messages,
    );
    // uuid: String?
    Object? uuid = state.string(
      state.read(input, 'uuid'),
      path,
      'uuid',
      _messages,
    );
    // ip: String?
    Object? ip = state.string(state.read(input, 'ip'), path, 'ip', _messages);
    // regex: String?
    Object? regex = state.string(
      state.read(input, 'regex'),
      path,
      'regex',
      _messages,
    );
    // inList: String?
    Object? inList = state.string(
      state.read(input, 'in_list'),
      path,
      'in_list',
      _messages,
    );
    // notIn: String?
    Object? notIn = state.string(
      state.read(input, 'not_in'),
      path,
      'not_in',
      _messages,
    );
    // starts: String?
    Object? starts = state.string(
      state.read(input, 'starts'),
      path,
      'starts',
      _messages,
    );
    // ends: String?
    Object? ends = state.string(
      state.read(input, 'ends'),
      path,
      'ends',
      _messages,
    );
    // alpha: String?
    Object? alpha = state.string(
      state.read(input, 'alpha'),
      path,
      'alpha',
      _messages,
    );
    // alnum: String?
    Object? alnum = state.string(
      state.read(input, 'alnum'),
      path,
      'alnum',
      _messages,
    );
    // dash: String?
    Object? dash = state.string(
      state.read(input, 'dash'),
      path,
      'dash',
      _messages,
    );
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (len is String) {
      if (!(len.runes.length >= 2 && len.runes.length <= 4)) {
        state.fail(
          path,
          'len',
          IssueCodes.lengthBetween,
          DefaultMessages.lengthBetween,
          len,
          params: const <String, Object?>{'min': 2, 'max': 4},
          messages: _messages,
        );
      }
    }
    if (exact is String) {
      if (!(exact.runes.length == 3)) {
        state.fail(
          path,
          'exact',
          IssueCodes.length,
          DefaultMessages.length,
          exact,
          params: const <String, Object?>{'length': 3},
          messages: _messages,
        );
      }
    }
    if (lenMin is String) {
      if (!(lenMin.runes.length >= 2)) {
        state.fail(
          path,
          'len_min',
          IssueCodes.minLength,
          DefaultMessages.minLength,
          lenMin,
          params: const <String, Object?>{'min': 2},
          messages: _messages,
        );
      }
    }
    if (minLen is String) {
      if (!(minLen.runes.length >= 2)) {
        state.fail(
          path,
          'min_len',
          IssueCodes.minLength,
          DefaultMessages.minLength,
          minLen,
          params: const <String, Object?>{'min': 2},
          messages: _messages,
        );
      }
    }
    if (maxLen is String) {
      if (!(maxLen.runes.length <= 3)) {
        state.fail(
          path,
          'max_len',
          IssueCodes.maxLength,
          DefaultMessages.maxLength,
          maxLen,
          params: const <String, Object?>{'max': 3},
          messages: _messages,
        );
      }
    }
    if (email is String) {
      if (!(Patterns.email.hasMatch(email))) {
        state.fail(
          path,
          'email',
          IssueCodes.email,
          DefaultMessages.email,
          email,
          messages: _messages,
        );
      }
    }
    if (url is String) {
      if (!(DtoChecks.url(url))) {
        state.fail(
          path,
          'url',
          IssueCodes.url,
          DefaultMessages.url,
          url,
          messages: _messages,
        );
      }
    }
    if (uuid is String) {
      if (!(Patterns.uuid.hasMatch(uuid))) {
        state.fail(
          path,
          'uuid',
          IssueCodes.uuid,
          DefaultMessages.uuid,
          uuid,
          messages: _messages,
        );
      }
    }
    if (ip is String) {
      if (!(DtoChecks.ip(ip))) {
        state.fail(
          path,
          'ip',
          IssueCodes.ip,
          DefaultMessages.ip,
          ip,
          messages: _messages,
        );
      }
    }
    if (regex is String) {
      if (!(_r0.hasMatch(regex))) {
        state.fail(
          path,
          'regex',
          IssueCodes.regex,
          DefaultMessages.regex,
          regex,
          messages: _messages,
        );
      }
    }
    if (inList is String) {
      if (!(const <String>{'a', 'b'}.contains(inList))) {
        state.fail(
          path,
          'in_list',
          IssueCodes.inList,
          DefaultMessages.inList,
          inList,
          params: const <String, Object?>{'values': 'a, and b'},
          messages: _messages,
        );
      }
    }
    if (notIn is String) {
      if (!(!const <String>{'root'}.contains(notIn))) {
        state.fail(
          path,
          'not_in',
          IssueCodes.notIn,
          DefaultMessages.notIn,
          notIn,
          messages: _messages,
        );
      }
    }
    if (starts is String) {
      if (!(starts.startsWith('dox'))) {
        state.fail(
          path,
          'starts',
          IssueCodes.startWith,
          DefaultMessages.startWith,
          starts,
          params: const <String, Object?>{'prefix': 'dox'},
          messages: _messages,
        );
      }
    }
    if (ends is String) {
      if (!(ends.endsWith('.dev'))) {
        state.fail(
          path,
          'ends',
          IssueCodes.endWith,
          DefaultMessages.endWith,
          ends,
          params: const <String, Object?>{'suffix': '.dev'},
          messages: _messages,
        );
      }
    }
    if (alpha is String) {
      if (!(Patterns.alpha.hasMatch(alpha))) {
        state.fail(
          path,
          'alpha',
          IssueCodes.alpha,
          DefaultMessages.alpha,
          alpha,
          messages: _messages,
        );
      }
    }
    if (alnum is String) {
      if (!(Patterns.alphaNumeric.hasMatch(alnum))) {
        state.fail(
          path,
          'alnum',
          IssueCodes.alphaNumeric,
          DefaultMessages.alphaNumeric,
          alnum,
          messages: _messages,
        );
      }
    }
    if (dash is String) {
      if (!(Patterns.alphaDash.hasMatch(dash))) {
        state.fail(
          path,
          'dash',
          IssueCodes.alphaDash,
          DefaultMessages.alphaDash,
          dash,
          messages: _messages,
        );
      }
    }
    if (state.issues.length != issuesBefore) return null;
    return TextRules(
      len: len is Undefined ? null : len as String?,
      exact: exact is Undefined ? null : exact as String?,
      lenMin: lenMin is Undefined ? null : lenMin as String?,
      minLen: minLen is Undefined ? null : minLen as String?,
      maxLen: maxLen is Undefined ? null : maxLen as String?,
      email: email is Undefined ? null : email as String?,
      url: url is Undefined ? null : url as String?,
      uuid: uuid is Undefined ? null : uuid as String?,
      ip: ip is Undefined ? null : ip as String?,
      regex: regex is Undefined ? null : regex as String?,
      inList: inList is Undefined ? null : inList as String?,
      notIn: notIn is Undefined ? null : notIn as String?,
      starts: starts is Undefined ? null : starts as String?,
      ends: ends is Undefined ? null : ends as String?,
      alpha: alpha is Undefined ? null : alpha as String?,
      alnum: alnum is Undefined ? null : alnum as String?,
      dash: dash is Undefined ? null : dash as String?,
    );
  }

  @override
  TextRules fromMap(Map<String, dynamic> map) {
    return TextRules(
      len: map['len'] == null ? null : (map['len'] as String),
      exact: map['exact'] == null ? null : (map['exact'] as String),
      lenMin: map['len_min'] == null ? null : (map['len_min'] as String),
      minLen: map['min_len'] == null ? null : (map['min_len'] as String),
      maxLen: map['max_len'] == null ? null : (map['max_len'] as String),
      email: map['email'] == null ? null : (map['email'] as String),
      url: map['url'] == null ? null : (map['url'] as String),
      uuid: map['uuid'] == null ? null : (map['uuid'] as String),
      ip: map['ip'] == null ? null : (map['ip'] as String),
      regex: map['regex'] == null ? null : (map['regex'] as String),
      inList: map['in_list'] == null ? null : (map['in_list'] as String),
      notIn: map['not_in'] == null ? null : (map['not_in'] as String),
      starts: map['starts'] == null ? null : (map['starts'] as String),
      ends: map['ends'] == null ? null : (map['ends'] as String),
      alpha: map['alpha'] == null ? null : (map['alpha'] as String),
      alnum: map['alnum'] == null ? null : (map['alnum'] as String),
      dash: map['dash'] == null ? null : (map['dash'] as String),
    );
  }

  @override
  Map<String, dynamic> toMap(TextRules dto) {
    return <String, dynamic>{
      'len': dto.len,
      'exact': dto.exact,
      'len_min': dto.lenMin,
      'min_len': dto.minLen,
      'max_len': dto.maxLen,
      'email': dto.email,
      'url': dto.url,
      'uuid': dto.uuid,
      'ip': dto.ip,
      'regex': dto.regex,
      'in_list': dto.inList,
      'not_in': dto.notIn,
      'starts': dto.starts,
      'ends': dto.ends,
      'alpha': dto.alpha,
      'alnum': dto.alnum,
      'dash': dto.dash,
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as TextRules));

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
          'pattern': '^[a-zA-Z0-9_-]+\$',
        },
      },
    };
  }
}

/// The checks, the converter and the JSON Schema of [ChangeText].
const DtoSchema<ChangeText> $ChangeTextDto = _$ChangeTextDto();

class _$ChangeTextDto extends DtoSchema<ChangeText>
    implements JsonObjectWriter {
  const _$ChangeTextDto();

  static const Map<String, String> _messages = <String, String>{};

  @override
  Type get type => ChangeText;

  @override
  String get name => 'ChangeText';

  @override
  bool get usesRequiredWhen => false;

  @override
  ChangeText? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // trimmed: String?
    Object? trimmed = state.string(
      state.read(input, 'trimmed'),
      path,
      'trimmed',
      _messages,
      trim: true,
    );
    // lower: String?
    Object? lower = state.string(
      state.read(input, 'lower'),
      path,
      'lower',
      _messages,
      trim: true,
      textCase: 1,
    );
    // upper: String?
    Object? upper = state.string(
      state.read(input, 'upper'),
      path,
      'upper',
      _messages,
      textCase: 2,
    );
    // keep: String?
    Object? keep = state.string(
      state.read(input, 'keep'),
      path,
      'keep',
      _messages,
      allowEmpty: true,
    );
    // blank: String?
    Object? blank = state.string(
      state.read(input, 'blank'),
      path,
      'blank',
      _messages,
      trim: true,
    );
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (state.issues.length != issuesBefore) return null;
    return ChangeText(
      trimmed: trimmed is Undefined ? null : trimmed as String?,
      lower: lower is Undefined ? null : lower as String?,
      upper: upper is Undefined ? null : upper as String?,
      keep: keep is Undefined ? null : keep as String?,
      blank: blank is Undefined ? null : blank as String?,
    );
  }

  @override
  ChangeText fromMap(Map<String, dynamic> map) {
    return ChangeText(
      trimmed: map['trimmed'] == null ? null : (map['trimmed'] as String),
      lower: map['lower'] == null ? null : (map['lower'] as String),
      upper: map['upper'] == null ? null : (map['upper'] as String),
      keep: map['keep'] == null ? null : (map['keep'] as String),
      blank: map['blank'] == null ? null : (map['blank'] as String),
    );
  }

  @override
  Map<String, dynamic> toMap(ChangeText dto) {
    return <String, dynamic>{
      'trimmed': dto.trimmed,
      'lower': dto.lower,
      'upper': dto.upper,
      'keep': dto.keep,
      'blank': dto.blank,
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as ChangeText));

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

class _$NumberRulesDto extends DtoSchema<NumberRules>
    implements JsonObjectWriter {
  const _$NumberRulesDto();

  static const Map<String, String> _messages = <String, String>{};

  @override
  Type get type => NumberRules;

  @override
  String get name => 'NumberRules';

  @override
  bool get usesRequiredWhen => false;

  @override
  NumberRules? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // min: int?
    Object? min = state.integer(
      state.read(input, 'min'),
      path,
      'min',
      _messages,
    );
    // max: int?
    Object? max = state.integer(
      state.read(input, 'max'),
      path,
      'max',
      _messages,
    );
    // range: num?
    Object? range = state.number(
      state.read(input, 'range'),
      path,
      'range',
      _messages,
    );
    // positive: int?
    Object? positive = state.integer(
      state.read(input, 'positive'),
      path,
      'positive',
      _messages,
    );
    // gt: double?
    Object? gt = state.decimal(state.read(input, 'gt'), path, 'gt', _messages);
    // lt: num?
    Object? lt = state.number(state.read(input, 'lt'), path, 'lt', _messages);
    // inNum: int?
    Object? inNum = state.integer(
      state.read(input, 'in_num'),
      path,
      'in_num',
      _messages,
    );
    // notInNum: int?
    Object? notInNum = state.integer(
      state.read(input, 'not_in_num'),
      path,
      'not_in_num',
      _messages,
    );
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (min is int) {
      if (!(min >= 18)) {
        state.fail(
          path,
          'min',
          IssueCodes.min,
          DefaultMessages.min,
          min,
          params: const <String, Object?>{'min': 18},
          messages: _messages,
        );
      }
    }
    if (max is int) {
      if (!(max <= 100)) {
        state.fail(
          path,
          'max',
          IssueCodes.max,
          DefaultMessages.max,
          max,
          params: const <String, Object?>{'max': 100},
          messages: _messages,
        );
      }
    }
    if (range is num) {
      if (!(range >= 1 && range <= 10)) {
        state.fail(
          path,
          'range',
          IssueCodes.between,
          DefaultMessages.between,
          range,
          params: const <String, Object?>{'min': 1, 'max': 10},
          messages: _messages,
        );
      }
    }
    if (positive is int) {
      if (!(positive > 0)) {
        state.fail(
          path,
          'positive',
          IssueCodes.greaterThan,
          DefaultMessages.greaterThan,
          positive,
          params: const <String, Object?>{'min': 0},
          messages: _messages,
        );
      }
    }
    if (gt is double) {
      if (!(gt > 0.5)) {
        state.fail(
          path,
          'gt',
          IssueCodes.greaterThan,
          DefaultMessages.greaterThan,
          gt,
          params: const <String, Object?>{'min': 0.5},
          messages: _messages,
        );
      }
    }
    if (lt is num) {
      if (!(lt < 100)) {
        state.fail(
          path,
          'lt',
          IssueCodes.lessThan,
          DefaultMessages.lessThan,
          lt,
          params: const <String, Object?>{'max': 100},
          messages: _messages,
        );
      }
    }
    if (inNum is int) {
      if (!(const <num>{1, 2, 3}.contains(inNum))) {
        state.fail(
          path,
          'in_num',
          IssueCodes.inList,
          DefaultMessages.inList,
          inNum,
          params: const <String, Object?>{'values': '1, 2, and 3'},
          messages: _messages,
        );
      }
    }
    if (notInNum is int) {
      if (!(!const <num>{0}.contains(notInNum))) {
        state.fail(
          path,
          'not_in_num',
          IssueCodes.notIn,
          DefaultMessages.notIn,
          notInNum,
          messages: _messages,
        );
      }
    }
    if (state.issues.length != issuesBefore) return null;
    return NumberRules(
      min: min is Undefined ? null : min as int?,
      max: max is Undefined ? null : max as int?,
      range: range is Undefined ? null : range as num?,
      positive: positive is Undefined ? null : positive as int?,
      gt: gt is Undefined ? null : gt as double?,
      lt: lt is Undefined ? null : lt as num?,
      inNum: inNum is Undefined ? null : inNum as int?,
      notInNum: notInNum is Undefined ? null : notInNum as int?,
    );
  }

  @override
  NumberRules fromMap(Map<String, dynamic> map) {
    return NumberRules(
      min: map['min'] == null ? null : ((map['min'] as num).toInt()),
      max: map['max'] == null ? null : ((map['max'] as num).toInt()),
      range: map['range'] == null ? null : (map['range'] as num),
      positive: map['positive'] == null
          ? null
          : ((map['positive'] as num).toInt()),
      gt: map['gt'] == null ? null : ((map['gt'] as num).toDouble()),
      lt: map['lt'] == null ? null : (map['lt'] as num),
      inNum: map['in_num'] == null ? null : ((map['in_num'] as num).toInt()),
      notInNum: map['not_in_num'] == null
          ? null
          : ((map['not_in_num'] as num).toInt()),
    );
  }

  @override
  Map<String, dynamic> toMap(NumberRules dto) {
    return <String, dynamic>{
      'min': dto.min,
      'max': dto.max,
      'range': dto.range,
      'positive': dto.positive,
      'gt': dto.gt,
      'lt': dto.lt,
      'in_num': dto.inNum,
      'not_in_num': dto.notInNum,
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as NumberRules));

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

class _$ListRulesDto extends DtoSchema<ListRules> implements JsonObjectWriter {
  const _$ListRulesDto();

  static const Map<String, String> _messages = <String, String>{};

  @override
  Type get type => ListRules;

  @override
  String get name => 'ListRules';

  @override
  bool get usesRequiredWhen => false;

  @override
  ListRules? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // minItems: List<int>?
    Object? minItems = state.list(
      state.read(input, 'min_items'),
      path,
      'min_items',
      _messages,
    );
    if (minItems is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'min_items'];
      List<int> o0 = <int>[];
      for (int i0 = 0; i0 < minItems.length; i0++) {
        Object? x0 = state.integer(minItems[i0], q0, i0, _messages);
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as int);
        }
      }
      minItems = state.issues.length != b0 ? invalid : o0;
    }
    // maxItems: List<String>?
    Object? maxItems = state.list(
      state.read(input, 'max_items'),
      path,
      'max_items',
      _messages,
    );
    if (maxItems is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'max_items'];
      List<String> o0 = <String>[];
      for (int i0 = 0; i0 < maxItems.length; i0++) {
        Object? x0 = state.string(maxItems[i0], q0, i0, _messages);
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as String);
        }
      }
      maxItems = state.issues.length != b0 ? invalid : o0;
    }
    // unique: List<String>?
    Object? unique = state.list(
      state.read(input, 'unique'),
      path,
      'unique',
      _messages,
    );
    if (unique is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'unique'];
      List<String> o0 = <String>[];
      for (int i0 = 0; i0 < unique.length; i0++) {
        Object? x0 = state.string(unique[i0], q0, i0, _messages);
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as String);
        }
      }
      unique = state.issues.length != b0 ? invalid : o0;
    }
    // emails: List<String>?
    Object? emails = state.list(
      state.read(input, 'emails'),
      path,
      'emails',
      _messages,
    );
    if (emails is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'emails'];
      List<String> o0 = <String>[];
      for (int i0 = 0; i0 < emails.length; i0++) {
        Object? x0 = state.string(emails[i0], q0, i0, _messages);
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as String);
        }
      }
      emails = state.issues.length != b0 ? invalid : o0;
    }
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (minItems is List<int>) {
      if (!(minItems.length >= 1)) {
        state.fail(
          path,
          'min_items',
          IssueCodes.minItems,
          DefaultMessages.minItems,
          minItems,
          params: const <String, Object?>{'min': 1},
          messages: _messages,
        );
      }
    }
    if (maxItems is List<String>) {
      if (!(maxItems.length <= 2)) {
        state.fail(
          path,
          'max_items',
          IssueCodes.maxItems,
          DefaultMessages.maxItems,
          maxItems,
          params: const <String, Object?>{'max': 2},
          messages: _messages,
        );
      }
    }
    if (unique is List<String>) {
      if (!(!DtoChecks.hasDuplicates(unique))) {
        state.fail(
          path,
          'unique',
          IssueCodes.uniqueItems,
          DefaultMessages.uniqueItems,
          unique,
          messages: _messages,
        );
      }
    }
    if (emails is List<String>) {
      List<Object> q = <Object>[...path, 'emails'];
      for (int i = 0; i < emails.length; i++) {
        String v = emails[i];
        if (!(Patterns.email.hasMatch(v))) {
          state.fail(
            q,
            i,
            IssueCodes.email,
            DefaultMessages.email,
            v,
            messages: _messages,
          );
        }
      }
    }
    if (state.issues.length != issuesBefore) return null;
    return ListRules(
      minItems: minItems is Undefined ? null : minItems as List<int>?,
      maxItems: maxItems is Undefined ? null : maxItems as List<String>?,
      unique: unique is Undefined ? null : unique as List<String>?,
      emails: emails is Undefined ? null : emails as List<String>?,
    );
  }

  @override
  ListRules fromMap(Map<String, dynamic> map) {
    return ListRules(
      minItems: map['min_items'] == null
          ? null
          : (<int>[
              for (Object? x0 in map['min_items'] as List<dynamic>)
                (x0 as num).toInt(),
            ]),
      maxItems: map['max_items'] == null
          ? null
          : (<String>[
              for (Object? x0 in map['max_items'] as List<dynamic>)
                x0 as String,
            ]),
      unique: map['unique'] == null
          ? null
          : (<String>[
              for (Object? x0 in map['unique'] as List<dynamic>) x0 as String,
            ]),
      emails: map['emails'] == null
          ? null
          : (<String>[
              for (Object? x0 in map['emails'] as List<dynamic>) x0 as String,
            ]),
    );
  }

  @override
  Map<String, dynamic> toMap(ListRules dto) {
    return <String, dynamic>{
      'min_items': dto.minItems,
      'max_items': dto.maxItems,
      'unique': dto.unique,
      'emails': dto.emails,
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as ListRules));

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

class _$DateRulesDto extends DtoSchema<DateRules> implements JsonObjectWriter {
  const _$DateRulesDto();

  static const Map<String, String> _messages = <String, String>{};

  static final DateTime _d0 = DateTime.fromMicrosecondsSinceEpoch(
    946684800000000,
    isUtc: true,
  );

  @override
  Type get type => DateRules;

  @override
  String get name => 'DateRules';

  @override
  bool get usesRequiredWhen => false;

  @override
  DateRules? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // after: DateTime?
    Object? after = state.date(
      state.read(input, 'after'),
      path,
      'after',
      _messages,
    );
    // before: DateTime?
    Object? before = state.date(
      state.read(input, 'before'),
      path,
      'before',
      _messages,
    );
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (after is DateTime) {
      if (!(after.isAfter(_d0))) {
        state.fail(
          path,
          'after',
          IssueCodes.after,
          DefaultMessages.after,
          after,
          params: const <String, Object?>{'date': '2000-01-01'},
          messages: _messages,
        );
      }
    }
    if (before is DateTime) {
      if (!(before.isBefore(state.now))) {
        state.fail(
          path,
          'before',
          IssueCodes.before,
          DefaultMessages.before,
          before,
          params: const <String, Object?>{'date': 'now'},
          messages: _messages,
        );
      }
    }
    if (state.issues.length != issuesBefore) return null;
    return DateRules(
      after: after is Undefined ? null : after as DateTime?,
      before: before is Undefined ? null : before as DateTime?,
    );
  }

  @override
  DateRules fromMap(Map<String, dynamic> map) {
    return DateRules(
      after: map['after'] == null
          ? null
          : (DateTime.parse(map['after'] as String).toUtc()),
      before: map['before'] == null
          ? null
          : (DateTime.parse(map['before'] as String).toUtc()),
    );
  }

  @override
  Map<String, dynamic> toMap(DateRules dto) {
    DateTime? after = dto.after;
    DateTime? before = dto.before;
    return <String, dynamic>{
      'after': after == null ? null : after.toIso8601String(),
      'before': before == null ? null : before.toIso8601String(),
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as DateRules));

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

class _$AllTypesDto extends DtoSchema<AllTypes> implements JsonObjectWriter {
  const _$AllTypesDto();

  static const Map<String, String> _messages = <String, String>{};

  @override
  Type get type => AllTypes;

  @override
  String get name => 'AllTypes';

  @override
  bool get usesRequiredWhen => false;

  @override
  AllTypes? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // s: String?
    Object? s = state.string(state.read(input, 's'), path, 's', _messages);
    // i: int?
    Object? iValue = state.integer(
      state.read(input, 'i'),
      path,
      'i',
      _messages,
    );
    // d: double?
    Object? d = state.decimal(state.read(input, 'd'), path, 'd', _messages);
    // n: num?
    Object? n = state.number(state.read(input, 'n'), path, 'n', _messages);
    // b: bool?
    Object? b = state.boolean(state.read(input, 'b'), path, 'b', _messages);
    // dt: DateTime?
    Object? dt = state.date(state.read(input, 'dt'), path, 'dt', _messages);
    // role: Role?
    Object? role = state.enumName(
      state.read(input, 'role'),
      path,
      'role',
      _messages,
      const <String>['admin', 'user'],
    );
    if (role is String) {
      role = switch (role) {
        'admin' => Role.admin,
        _ => Role.user,
      };
    }
    // list: List<int>?
    Object? list = state.list(
      state.read(input, 'list'),
      path,
      'list',
      _messages,
    );
    if (list is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'list'];
      List<int> o0 = <int>[];
      for (int i0 = 0; i0 < list.length; i0++) {
        Object? x0 = state.integer(list[i0], q0, i0, _messages);
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as int);
        }
      }
      list = state.issues.length != b0 ? invalid : o0;
    }
    // map: Map<String, int>?
    Object? map = state.object(
      state.read(input, 'map'),
      path,
      'map',
      _messages,
    );
    if (map is Map) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'map'];
      Map<String, int> o0 = <String, int>{};
      for (MapEntry<dynamic, dynamic> n0 in map.entries) {
        String k0 = '${n0.key}';
        Object? x0 = state.integer(n0.value, q0, k0, _messages);
        if (x0 == null || x0 is Undefined) {
          state.required(q0, k0, _messages);
        } else if (x0 is! Invalid) {
          o0[k0] = x0 as int;
        }
      }
      map = state.issues.length != b0 ? invalid : o0;
    }
    // any: Object?
    Object? any = state.read(input, 'any');
    // raw: Map<String, dynamic>?
    Object? raw = state.object(
      state.read(input, 'raw'),
      path,
      'raw',
      _messages,
    );
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (state.issues.length != issuesBefore) return null;
    return AllTypes(
      s: s is Undefined ? null : s as String?,
      i: iValue is Undefined ? null : iValue as int?,
      d: d is Undefined ? null : d as double?,
      n: n is Undefined ? null : n as num?,
      b: b is Undefined ? null : b as bool?,
      dt: dt is Undefined ? null : dt as DateTime?,
      role: role is Undefined ? null : role as Role?,
      list: list is Undefined ? null : list as List<int>?,
      map: map is Undefined ? null : map as Map<String, int>?,
      any: any is Undefined ? null : any,
      raw: raw is Undefined ? null : raw as Map<String, dynamic>?,
    );
  }

  @override
  AllTypes fromMap(Map<String, dynamic> map) {
    return AllTypes(
      s: map['s'] == null ? null : (map['s'] as String),
      i: map['i'] == null ? null : ((map['i'] as num).toInt()),
      d: map['d'] == null ? null : ((map['d'] as num).toDouble()),
      n: map['n'] == null ? null : (map['n'] as num),
      b: map['b'] == null ? null : (map['b'] as bool),
      dt: map['dt'] == null
          ? null
          : (DateTime.parse(map['dt'] as String).toUtc()),
      role: map['role'] == null
          ? null
          : (Role.values.byName(map['role'] as String)),
      list: map['list'] == null
          ? null
          : (<int>[
              for (Object? x0 in map['list'] as List<dynamic>)
                (x0 as num).toInt(),
            ]),
      map: map['map'] == null
          ? null
          : (<String, int>{
              for (MapEntry<dynamic, dynamic> x0
                  in (map['map'] as Map<dynamic, dynamic>).entries)
                x0.key as String: (x0.value as num).toInt(),
            }),
      any: map['any'],
      raw: map['raw'] == null ? null : (map['raw'] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toMap(AllTypes dto) {
    DateTime? dt = dto.dt;
    Role? role = dto.role;
    return <String, dynamic>{
      's': dto.s,
      'i': dto.i,
      'd': dto.d,
      'n': dto.n,
      'b': dto.b,
      'dt': dt == null ? null : dt.toIso8601String(),
      'role': role == null ? null : role.name,
      'list': dto.list,
      'map': dto.map,
      'any': dto.any,
      'raw': dto.raw,
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as AllTypes));

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

class _$SearchUsersDto extends DtoSchema<SearchUsers>
    implements JsonObjectWriter {
  const _$SearchUsersDto();

  static const Map<String, String> _messages = <String, String>{};

  @override
  Type get type => SearchUsers;

  @override
  String get name => 'SearchUsers';

  @override
  Source get source => Source.query;

  @override
  bool get usesRequiredWhen => false;

  @override
  SearchUsers? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // q: String?
    Object? qValue = state.string(state.read(input, 'q'), path, 'q', _messages);
    // page: int
    Object? page = state.integer(
      state.read(input, 'page'),
      path,
      'page',
      _messages,
    );
    if (page == null) state.required(path, 'page', _messages);
    // tags: List<String>
    Object? tags = state.list(
      state.read(input, 'tags'),
      path,
      'tags',
      _messages,
    );
    if (tags is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'tags'];
      List<String> o0 = <String>[];
      for (int i0 = 0; i0 < tags.length; i0++) {
        Object? x0 = state.string(tags[i0], q0, i0, _messages);
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as String);
        }
      }
      tags = state.issues.length != b0 ? invalid : o0;
    }
    if (tags == null) state.required(path, 'tags', _messages);
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (state.issues.length != issuesBefore) return null;
    return SearchUsers(
      q: qValue is Undefined ? null : qValue as String?,
      page: page is Undefined ? 1 : page as int,
      tags: tags is Undefined ? const <String>[] : tags as List<String>,
    );
  }

  @override
  SearchUsers fromMap(Map<String, dynamic> map) {
    return SearchUsers(
      q: map['q'] == null ? null : (map['q'] as String),
      page: map.containsKey('page') ? (map['page'] as num).toInt() : 1,
      tags: map.containsKey('tags')
          ? <String>[
              for (Object? x0 in map['tags'] as List<dynamic>) x0 as String,
            ]
          : const <String>[],
    );
  }

  @override
  Map<String, dynamic> toMap(SearchUsers dto) {
    return <String, dynamic>{'q': dto.q, 'page': dto.page, 'tags': dto.tags};
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as SearchUsers));

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

class _$StrictInputDto extends DtoSchema<StrictInput>
    implements JsonObjectWriter {
  const _$StrictInputDto();

  static const Map<String, String> _messages = <String, String>{};

  static const Set<String> _keys = <String>{'name'};

  @override
  Type get type => StrictInput;

  @override
  String get name => 'StrictInput';

  @override
  bool get usesRequiredWhen => false;

  @override
  StrictInput? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    for (Object? k in input.keys) {
      if (!_keys.contains(k)) {
        state.fail(
          path,
          '$k',
          IssueCodes.unrecognizedKeys,
          DefaultMessages.notAllowed,
          input[k],
          messages: _messages,
        );
      }
    }
    // name: String
    Object? name = state.string(
      state.read(input, 'name'),
      path,
      'name',
      _messages,
    );
    if (name == null || name is Undefined)
      state.required(path, 'name', _messages);
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (state.issues.length != issuesBefore) return null;
    return StrictInput(name: name as String);
  }

  @override
  StrictInput fromMap(Map<String, dynamic> map) {
    return StrictInput(name: map['name'] as String);
  }

  @override
  Map<String, dynamic> toMap(StrictInput dto) {
    return <String, dynamic>{'name': dto.name};
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as StrictInput));

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

class _$WithMessagesDto extends DtoSchema<WithMessages>
    implements JsonObjectWriter {
  const _$WithMessagesDto();

  static const Map<String, String> _messages = <String, String>{
    'email.required': 'We need your email',
    'required': 'Please fill in {field}',
    'integer': 'The {field} must be a number',
  };

  @override
  Type get type => WithMessages;

  @override
  String get name => 'WithMessages';

  @override
  bool get usesRequiredWhen => false;

  @override
  WithMessages? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // email: String
    Object? email = state.string(
      state.read(input, 'email'),
      path,
      'email',
      _messages,
    );
    if (email == null || email is Undefined)
      state.required(path, 'email', _messages);
    // name: String
    Object? name = state.string(
      state.read(input, 'name'),
      path,
      'name',
      _messages,
    );
    if (name == null || name is Undefined)
      state.required(path, 'name', _messages);
    // age: int?
    Object? age = state.integer(
      state.read(input, 'age'),
      path,
      'age',
      _messages,
    );
    // nick: String?
    Object? nick = state.string(
      state.read(input, 'nick'),
      path,
      'nick',
      _messages,
    );
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (nick is String) {
      if (!(nick.runes.length >= 3)) {
        state.fail(
          path,
          'nick',
          IssueCodes.minLength,
          DefaultMessages.minLength,
          nick,
          params: const <String, Object?>{'min': 3},
          message: 'At least {min} letters, please',
          messages: _messages,
        );
      }
    }
    if (state.issues.length != issuesBefore) return null;
    return WithMessages(
      email: email as String,
      name: name as String,
      age: age is Undefined ? null : age as int?,
      nick: nick is Undefined ? null : nick as String?,
    );
  }

  @override
  WithMessages fromMap(Map<String, dynamic> map) {
    return WithMessages(
      email: map['email'] as String,
      name: map['name'] as String,
      age: map['age'] == null ? null : ((map['age'] as num).toInt()),
      nick: map['nick'] == null ? null : (map['nick'] as String),
    );
  }

  @override
  Map<String, dynamic> toMap(WithMessages dto) {
    return <String, dynamic>{
      'email': dto.email,
      'name': dto.name,
      'age': dto.age,
      'nick': dto.nick,
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as WithMessages));

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

class _$SignUpKeysDto extends DtoSchema<SignUpKeys>
    implements JsonObjectWriter {
  const _$SignUpKeysDto();

  static const Map<String, String> _messages = <String, String>{};

  @override
  Type get type => SignUpKeys;

  @override
  String get name => 'SignUpKeys';

  @override
  bool get usesRequiredWhen => false;

  @override
  SignUpKeys? convert(Object? input, DtoState state, List<Object> path) {
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
    );
    if (firstName == null || firstName is Undefined)
      state.required(path, 'first_name', _messages);
    // email: String
    Object? email = state.string(
      state.read(input, 'emailAddress'),
      path,
      'emailAddress',
      _messages,
    );
    if (email == null || email is Undefined)
      state.required(path, 'emailAddress', _messages);
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (state.issues.length != issuesBefore) return null;
    return SignUpKeys(firstName: firstName as String, email: email as String);
  }

  @override
  SignUpKeys fromMap(Map<String, dynamic> map) {
    return SignUpKeys(
      firstName: map['first_name'] as String,
      email: map['emailAddress'] as String,
    );
  }

  @override
  Map<String, dynamic> toMap(SignUpKeys dto) {
    return <String, dynamic>{
      'first_name': dto.firstName,
      'emailAddress': dto.email,
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as SignUpKeys));

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

class _$CamelKeysDto extends DtoSchema<CamelKeys> implements JsonObjectWriter {
  const _$CamelKeysDto();

  static const Map<String, String> _messages = <String, String>{};

  @override
  Type get type => CamelKeys;

  @override
  String get name => 'CamelKeys';

  @override
  bool get usesRequiredWhen => false;

  @override
  CamelKeys? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // firstName: String
    Object? firstName = state.string(
      state.read(input, 'firstName'),
      path,
      'firstName',
      _messages,
    );
    if (firstName == null || firstName is Undefined)
      state.required(path, 'firstName', _messages);
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (state.issues.length != issuesBefore) return null;
    return CamelKeys(firstName: firstName as String);
  }

  @override
  CamelKeys fromMap(Map<String, dynamic> map) {
    return CamelKeys(firstName: map['firstName'] as String);
  }

  @override
  Map<String, dynamic> toMap(CamelKeys dto) {
    return <String, dynamic>{'firstName': dto.firstName};
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as CamelKeys));

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

class _$UpdateUserDto extends DtoSchema<UpdateUser>
    implements JsonObjectWriter {
  const _$UpdateUserDto();

  static const Map<String, String> _messages = <String, String>{};

  @override
  Type get type => UpdateUser;

  @override
  String get name => 'UpdateUser';

  @override
  bool get usesRequiredWhen => false;

  @override
  UpdateUser? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // bio: Maybe<String?>
    Object? bio = state.string(
      state.read(input, 'bio'),
      path,
      'bio',
      _messages,
    );
    // age: Maybe<int>
    Object? age = state.integer(
      state.read(input, 'age'),
      path,
      'age',
      _messages,
    );
    if (age == null || state.sentEmpty(age, input, 'age'))
      state.required(path, 'age', _messages);
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (bio is String) {
      if (!(bio.runes.length <= 5)) {
        state.fail(
          path,
          'bio',
          IssueCodes.maxLength,
          DefaultMessages.maxLength,
          bio,
          params: const <String, Object?>{'max': 5},
          messages: _messages,
        );
      }
    }
    if (state.issues.length != issuesBefore) return null;
    return UpdateUser(
      bio: bio is Undefined
          ? const Maybe<String?>.missing()
          : Maybe<String?>(bio as String?),
      age: age is Undefined
          ? const Maybe<int>.missing()
          : Maybe<int>(age as int),
    );
  }

  @override
  UpdateUser fromMap(Map<String, dynamic> map) {
    return UpdateUser(
      bio: map.containsKey('bio')
          ? Maybe<String?>(map['bio'] == null ? null : (map['bio'] as String))
          : const Maybe<String?>.missing(),
      age: map.containsKey('age')
          ? Maybe<int>((map['age'] as num).toInt())
          : const Maybe<int>.missing(),
    );
  }

  @override
  Map<String, dynamic> toMap(UpdateUser dto) {
    return <String, dynamic>{
      if (dto.bio case Maybe<String?>(isPresent: true, value: String? bio))
        'bio': bio,
      if (dto.age case Maybe<int>(isPresent: true, value: int age)) 'age': age,
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as UpdateUser));

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

/// The checks, the converter and the JSON Schema of [MoreRules].
const DtoSchema<MoreRules> $MoreRulesDto = _$MoreRulesDto();

class _$MoreRulesDto extends DtoSchema<MoreRules> implements JsonObjectWriter {
  const _$MoreRulesDto();

  static const Map<String, String> _messages = <String, String>{};

  @override
  Type get type => MoreRules;

  @override
  String get name => 'MoreRules';

  @override
  MoreRules? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // password: String?
    Object? password = state.string(
      state.read(input, 'password'),
      path,
      'password',
      _messages,
    );
    // emailAgain: String?
    Object? emailAgain = state.string(
      state.read(input, 'email_again'),
      path,
      'email_again',
      _messages,
    );
    // email: String?
    Object? email = state.string(
      state.read(input, 'email'),
      path,
      'email',
      _messages,
    );
    // type: String?
    Object? type = state.string(
      state.read(input, 'type'),
      path,
      'type',
      _messages,
    );
    // company: String?
    Object? company = state.string(
      state.read(input, 'company'),
      path,
      'company',
      _messages,
    );
    // countryCode: Maybe<String>
    Object? countryCode = state.string(
      state.read(input, 'country_code'),
      path,
      'country_code',
      _messages,
    );
    if (countryCode == null ||
        state.sentEmpty(countryCode, input, 'country_code'))
      state.required(path, 'country_code', _messages);
    // phone: String?
    Object? phone = state.string(
      state.read(input, 'phone'),
      path,
      'phone',
      _messages,
    );
    // meta: String?
    Object? meta = state.string(
      state.read(input, 'meta'),
      path,
      'meta',
      _messages,
    );
    // role: Role?
    Object? role = state.enumName(
      state.read(input, 'role'),
      path,
      'role',
      _messages,
      const <String>['admin', 'user'],
    );
    if (role is String) {
      role = switch (role) {
        'admin' => Role.admin,
        _ => Role.user,
      };
    }
    // adminCode: String?
    Object? adminCode = state.string(
      state.read(input, 'admin_code'),
      path,
      'admin_code',
      _messages,
    );
    // tags: List<String>?
    Object? tags = state.list(
      state.read(input, 'tags'),
      path,
      'tags',
      _messages,
    );
    if (tags is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'tags'];
      List<String> o0 = <String>[];
      for (int i0 = 0; i0 < tags.length; i0++) {
        Object? x0 = state.string(tags[i0], q0, i0, _messages);
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as String);
        }
      }
      tags = state.issues.length != b0 ? invalid : o0;
    }
    // pin: String?
    Object? pin = state.string(
      state.read(input, 'pin'),
      path,
      'pin',
      _messages,
    );
    // code: String?
    Object? code = state.string(
      state.read(input, 'code'),
      path,
      'code',
      _messages,
    );
    // day: String?
    Object? day = state.string(
      state.read(input, 'day'),
      path,
      'day',
      _messages,
    );
    // secret: String?
    Object? secret = state.string(
      state.read(input, 'secret'),
      path,
      'secret',
      _messages,
    );
    // planNote: String?
    Object? planNote = state.string(
      state.read(input, 'plan_note'),
      path,
      'plan_note',
      _messages,
    );
    // plan: String?
    Object? plan = state.string(
      state.read(input, 'plan'),
      path,
      'plan',
      _messages,
      trim: true,
      textCase: 1,
    );
    state.requiredWhen(
      const RequiredIf('type', 'company'),
      company,
      input,
      path,
      'company',
      _messages,
    );
    state.requiredWhen(
      const RequiredWith(<String>['phone']),
      countryCode,
      input,
      path,
      'country_code',
      _messages,
    );
    state.requiredWhen(
      const RequiredIf('role', Role.admin),
      adminCode,
      input,
      path,
      'admin_code',
      _messages,
    );
    state.requiredWhen(
      const RequiredWith(<String>['tag_source']),
      tags,
      input,
      path,
      'tags',
      _messages,
    );
    state.requiredWhen(
      const RequiredIf('plan', 'pro'),
      planNote,
      input,
      path,
      'plan_note',
      _messages,
    );
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (password is String) {
      if (!(const Confirmed().check(
        password,
        state.context(path, 'password', password),
      ))) {
        state.failRule(
          const Confirmed(),
          path,
          'password',
          password,
          _messages,
        );
      }
    }
    if (emailAgain is String) {
      if (!(const Same('email')
          .check(emailAgain, state.context(path, 'email_again', emailAgain)))) {
        state.failRule(
          const Same('email'),
          path,
          'email_again',
          emailAgain,
          _messages,
        );
      }
    }
    if (meta is String) {
      if (!(const Json().check(meta, state.context(path, 'meta', meta)))) {
        state.failRule(const Json(), path, 'meta', meta, _messages);
      }
    }
    if (pin is String) {
      if (!(const Digits(4).check(pin, state.context(path, 'pin', pin)))) {
        state.failRule(const Digits(4), path, 'pin', pin, _messages);
      }
    }
    if (code is String) {
      if (!(const DigitsBetween(
        4,
        6,
      ).check(code, state.context(path, 'code', code)))) {
        state.failRule(
          const DigitsBetween(4, 6),
          path,
          'code',
          code,
          _messages,
        );
      }
    }
    if (day is String) {
      if (!(const DateFormatted('Y-m-d')
          .check(day, state.context(path, 'day', day)))) {
        state.failRule(
          const DateFormatted('Y-m-d'),
          path,
          'day',
          day,
          _messages,
        );
      }
    }
    if (secret is String) {
      if (!(const Password(
        mixedCase: true,
        numbers: true,
        symbols: true,
      ).check(secret, state.context(path, 'secret', secret)))) {
        state.failRule(
          const Password(mixedCase: true, numbers: true, symbols: true),
          path,
          'secret',
          secret,
          _messages,
        );
      }
    }
    if (state.issues.length != issuesBefore) return null;
    return MoreRules(
      password: password is Undefined ? null : password as String?,
      emailAgain: emailAgain is Undefined ? null : emailAgain as String?,
      email: email is Undefined ? null : email as String?,
      type: type is Undefined ? null : type as String?,
      company: company is Undefined ? null : company as String?,
      countryCode: countryCode is Undefined
          ? const Maybe<String>.missing()
          : Maybe<String>(countryCode as String),
      phone: phone is Undefined ? null : phone as String?,
      meta: meta is Undefined ? null : meta as String?,
      role: role is Undefined ? null : role as Role?,
      adminCode: adminCode is Undefined ? null : adminCode as String?,
      tags: tags is Undefined ? null : tags as List<String>?,
      pin: pin is Undefined ? null : pin as String?,
      code: code is Undefined ? null : code as String?,
      day: day is Undefined ? null : day as String?,
      secret: secret is Undefined ? null : secret as String?,
      planNote: planNote is Undefined ? null : planNote as String?,
      plan: plan is Undefined ? null : plan as String?,
    );
  }

  @override
  MoreRules fromMap(Map<String, dynamic> map) {
    return MoreRules(
      password: map['password'] == null ? null : (map['password'] as String),
      emailAgain: map['email_again'] == null
          ? null
          : (map['email_again'] as String),
      email: map['email'] == null ? null : (map['email'] as String),
      type: map['type'] == null ? null : (map['type'] as String),
      company: map['company'] == null ? null : (map['company'] as String),
      countryCode: map.containsKey('country_code')
          ? Maybe<String>(map['country_code'] as String)
          : const Maybe<String>.missing(),
      phone: map['phone'] == null ? null : (map['phone'] as String),
      meta: map['meta'] == null ? null : (map['meta'] as String),
      role: map['role'] == null
          ? null
          : (Role.values.byName(map['role'] as String)),
      adminCode: map['admin_code'] == null
          ? null
          : (map['admin_code'] as String),
      tags: map['tags'] == null
          ? null
          : (<String>[
              for (Object? x0 in map['tags'] as List<dynamic>) x0 as String,
            ]),
      pin: map['pin'] == null ? null : (map['pin'] as String),
      code: map['code'] == null ? null : (map['code'] as String),
      day: map['day'] == null ? null : (map['day'] as String),
      secret: map['secret'] == null ? null : (map['secret'] as String),
      planNote: map['plan_note'] == null ? null : (map['plan_note'] as String),
      plan: map['plan'] == null ? null : (map['plan'] as String),
    );
  }

  @override
  Map<String, dynamic> toMap(MoreRules dto) {
    Role? role = dto.role;
    return <String, dynamic>{
      'password': dto.password,
      'email_again': dto.emailAgain,
      'email': dto.email,
      'type': dto.type,
      'company': dto.company,
      if (dto.countryCode case Maybe<String>(
        isPresent: true,
        value: String countryCode,
      ))
        'country_code': countryCode,
      'phone': dto.phone,
      'meta': dto.meta,
      'role': role == null ? null : role.name,
      'admin_code': dto.adminCode,
      'tags': dto.tags,
      'pin': dto.pin,
      'code': dto.code,
      'day': dto.day,
      'secret': dto.secret,
      'plan_note': dto.planNote,
      'plan': dto.plan,
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as MoreRules));

  @override
  Map<String, dynamic> toJsonSchema() {
    Map<String, dynamic> schema = <String, dynamic>{
      'type': 'object',
      'title': 'MoreRules',
      'properties': <String, dynamic>{
        'password': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'email_again': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'email': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'type': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'company': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'country_code': <String, dynamic>{'type': 'string'},
        'phone': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'meta': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'role': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'enum': <dynamic>['admin', 'user'],
        },
        'admin_code': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'tags': <String, dynamic>{
          'type': <dynamic>['array', 'null'],
          'items': <String, dynamic>{'type': 'string'},
        },
        'pin': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'code': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'day': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'secret': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'plan_note': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'plan': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
      },
    };
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'password',
    ], const Confirmed().toJsonSchema());
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'email_again',
    ], const Same('email').toJsonSchema());
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'meta',
    ], const Json().toJsonSchema());
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'pin',
    ], const Digits(4).toJsonSchema());
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'code',
    ], const DigitsBetween(4, 6).toJsonSchema());
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'day',
    ], const DateFormatted('Y-m-d').toJsonSchema());
    JsonSchemaTools.merge(
      schema,
      <String>['properties', 'secret'],
      const Password(
        mixedCase: true,
        numbers: true,
        symbols: true,
      ).toJsonSchema(),
    );
    return schema;
  }
}

/// The checks, the converter and the JSON Schema of [StrictPassword].
const DtoSchema<StrictPassword> $StrictPasswordDto = _$StrictPasswordDto();

class _$StrictPasswordDto extends DtoSchema<StrictPassword>
    implements JsonObjectWriter {
  const _$StrictPasswordDto();

  static const Map<String, String> _messages = <String, String>{};

  static const Set<String> _keys = <String>{
    'password',
    'password_confirmation',
  };

  @override
  Type get type => StrictPassword;

  @override
  String get name => 'StrictPassword';

  @override
  bool get usesRequiredWhen => false;

  @override
  StrictPassword? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    for (Object? k in input.keys) {
      if (!_keys.contains(k)) {
        state.fail(
          path,
          '$k',
          IssueCodes.unrecognizedKeys,
          DefaultMessages.notAllowed,
          input[k],
          messages: _messages,
        );
      }
    }
    // password: String
    Object? password = state.string(
      state.read(input, 'password'),
      path,
      'password',
      _messages,
    );
    if (password == null || password is Undefined)
      state.required(path, 'password', _messages);
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (password is String) {
      if (!(const Confirmed().check(
        password,
        state.context(path, 'password', password),
      ))) {
        state.failRule(
          const Confirmed(),
          path,
          'password',
          password,
          _messages,
        );
      }
    }
    if (state.issues.length != issuesBefore) return null;
    return StrictPassword(password: password as String);
  }

  @override
  StrictPassword fromMap(Map<String, dynamic> map) {
    return StrictPassword(password: map['password'] as String);
  }

  @override
  Map<String, dynamic> toMap(StrictPassword dto) {
    return <String, dynamic>{'password': dto.password};
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as StrictPassword));

  @override
  Map<String, dynamic> toJsonSchema() {
    Map<String, dynamic> schema = <String, dynamic>{
      'type': 'object',
      'title': 'StrictPassword',
      'properties': <String, dynamic>{
        'password': <String, dynamic>{'type': 'string'},
      },
      'required': <dynamic>['password'],
      'additionalProperties': false,
    };
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'password',
    ], const Confirmed().toJsonSchema());
    return schema;
  }
}
