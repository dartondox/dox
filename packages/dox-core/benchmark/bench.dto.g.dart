// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bench.dto.dart';

// **************************************************************************
// DoxDtoGenerator
// **************************************************************************

// ignore_for_file: type=lint

/// The checks, the converter and the JSON Schema of [CreateMember].
const DtoSchema<CreateMember> $CreateMemberDto = _$CreateMemberDto();

class _$CreateMemberDto extends DtoSchema<CreateMember> {
  const _$CreateMemberDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => CreateMember;

  @override
  String get name => 'CreateMember';

  @override
  CreateMember? convert(Object? input, DtoState s, List<Object> p) {
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
    // age: int
    Object? c2;
    c2 = s.integer(s.read(input, 'age'), p, 'age', _m);
    if (c2 == null || c2 is Undefined) s.required(p, 'age', _m);
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
    if (c3 == null || c3 is Undefined) s.required(p, 'role', _m);
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
    // active: bool
    Object? c5;
    c5 = s.boolean(s.read(input, 'active'), p, 'active', _m);
    if (c5 == null || c5 is Undefined) s.required(p, 'active', _m);
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
    return CreateMember(
      name: c0 as String,
      email: c1 as String,
      age: c2 as int,
      role: c3 as Role,
      tags: c4 is Undefined ? const <String>[] : c4 as List<String>,
      active: c5 as bool,
    );
  }

  @override
  CreateMember fromMap(Map<String, dynamic> m) {
    return CreateMember(
      name: m['name'] as String,
      email: m['email'] as String,
      age: (m['age'] as num).toInt(),
      role: Role.values.byName(m['role'] as String),
      tags: m.containsKey('tags')
          ? <String>[
              for (Object? x0 in m['tags'] as List<dynamic>) x0 as String,
            ]
          : const <String>[],
      active: m['active'] as bool,
    );
  }

  @override
  Map<String, dynamic> toMap(CreateMember o) {
    String f0 = o.name;
    String f1 = o.email;
    int f2 = o.age;
    Role f3 = o.role;
    List<String> f4 = o.tags;
    bool f5 = o.active;
    return <String, dynamic>{
      'name': f0,
      'email': f1,
      'age': f2,
      'role': f3.name,
      'tags': f4,
      'active': f5,
    };
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'CreateMember',
      'properties': <String, dynamic>{
        'name': <String, dynamic>{
          'type': 'string',
          'minLength': 3,
          'maxLength': 50,
        },
        'email': <String, dynamic>{'type': 'string', 'format': 'email'},
        'age': <String, dynamic>{'type': 'integer', 'minimum': 18},
        'role': <String, dynamic>{
          'type': 'string',
          'enum': <dynamic>['admin', 'user'],
        },
        'tags': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'type': 'string'},
          'maxItems': 5,
          'default': <dynamic>[],
        },
        'active': <String, dynamic>{'type': 'boolean'},
      },
      'required': <dynamic>['name', 'email', 'age', 'role', 'active'],
    };
  }
}
