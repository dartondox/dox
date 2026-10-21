// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dto.dart';

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
  bool get isAsync => true;

  @override
  CreateMember? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // email: String
    Object? c0;
    c0 = s.string(s.read(input, 'email'), p, 'email', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'email', _m);
    // teamId: int
    Object? c1;
    c1 = s.integer(s.read(input, 'team_id'), p, 'team_id', _m);
    if (c1 == null || c1 is Undefined) s.required(p, 'team_id', _m);
    // tagIds: List<int>
    Object? c2;
    c2 = s.list(s.read(input, 'tag_ids'), p, 'tag_ids', _m);
    if (c2 is List) {
      List<Object> q0 = <Object>[...p, 'tag_ids'];
      List<int> o0 = <int>[];
      for (int i0 = 0; i0 < c2.length; i0++) {
        Object? x0;
        x0 = s.integer(c2[i0], q0, i0, _m);
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as int);
        }
      }
      c2 = o0;
    }
    if (c2 == null) s.required(p, 'tag_ids', _m);
    if (s.issues.length != e) return null;
    if (c0 is String) {
      if (!(Patterns.email.hasMatch(c0))) {
        s.fail(
          p,
          'email',
          IssueCodes.email,
          DefaultMessages.email,
          c0,
          messages: _m,
        );
      }
    }
    if (s.issues.length != e) return null;
    return CreateMember(
      email: c0 as String,
      teamId: c1 as int,
      tagIds: c2 is Undefined ? const <int>[] : c2 as List<int>,
    );
  }

  @override
  Future<void> checkAsync(CreateMember o, DtoState s, List<Object> p) async {
    {
      String f = o.email;
      await s.asyncRule(
        const Unique('members', column: 'email'),
        f,
        p,
        'email',
        _m,
      );
    }
    {
      int f = o.teamId;
      await s.asyncRule(const Exists('teams'), f, p, 'team_id', _m);
    }
    {
      List<int> f = o.tagIds;
      await s.asyncItems(const Exists('tags'), f, p, 'tag_ids', _m);
    }
  }

  @override
  CreateMember fromMap(Map<String, dynamic> m) {
    return CreateMember(
      email: m['email'] as String,
      teamId: (m['team_id'] as num).toInt(),
      tagIds: m.containsKey('tag_ids')
          ? <int>[
              for (Object? x0 in m['tag_ids'] as List<dynamic>)
                (x0 as num).toInt(),
            ]
          : const <int>[],
    );
  }

  @override
  Map<String, dynamic> toMap(CreateMember o) {
    String f0 = o.email;
    int f1 = o.teamId;
    List<int> f2 = o.tagIds;
    return <String, dynamic>{'email': f0, 'team_id': f1, 'tag_ids': f2};
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    Map<String, dynamic> j = <String, dynamic>{
      'type': 'object',
      'title': 'CreateMember',
      'properties': <String, dynamic>{
        'email': <String, dynamic>{'type': 'string', 'format': 'email'},
        'team_id': <String, dynamic>{'type': 'integer'},
        'tag_ids': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'type': 'integer'},
          'default': <dynamic>[],
        },
      },
      'required': <dynamic>['email', 'team_id'],
    };
    JsonSchemaTools.merge(j, <String>[
      'properties',
      'email',
    ], const Unique('members', column: 'email').toJsonSchema());
    JsonSchemaTools.merge(j, <String>[
      'properties',
      'team_id',
    ], const Exists('teams').toJsonSchema());
    JsonSchemaTools.merge(j, <String>[
      'properties',
      'tag_ids',
      'items',
    ], const Exists('tags').toJsonSchema());
    return j;
  }
}

/// The checks, the converter and the JSON Schema of [UpdateMember].
const DtoSchema<UpdateMember> $UpdateMemberDto = _$UpdateMemberDto();

class _$UpdateMemberDto extends DtoSchema<UpdateMember> {
  const _$UpdateMemberDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => UpdateMember;

  @override
  String get name => 'UpdateMember';

  @override
  bool get isAsync => true;

  @override
  UpdateMember? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // email: String
    Object? c0;
    c0 = s.string(s.read(input, 'email'), p, 'email', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'email', _m);
    if (s.issues.length != e) return null;
    return UpdateMember(email: c0 as String);
  }

  @override
  Future<void> checkAsync(UpdateMember o, DtoState s, List<Object> p) async {
    {
      String f = o.email;
      await s.asyncRule(
        const Unique('members', column: 'email', ignoreParam: 'id'),
        f,
        p,
        'email',
        _m,
      );
    }
  }

  @override
  UpdateMember fromMap(Map<String, dynamic> m) {
    return UpdateMember(email: m['email'] as String);
  }

  @override
  Map<String, dynamic> toMap(UpdateMember o) {
    String f0 = o.email;
    return <String, dynamic>{'email': f0};
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    Map<String, dynamic> j = <String, dynamic>{
      'type': 'object',
      'title': 'UpdateMember',
      'properties': <String, dynamic>{
        'email': <String, dynamic>{'type': 'string'},
      },
      'required': <dynamic>['email'],
    };
    JsonSchemaTools.merge(
      j,
      <String>['properties', 'email'],
      const Unique(
        'members',
        column: 'email',
        ignoreParam: 'id',
      ).toJsonSchema(),
    );
    return j;
  }
}
