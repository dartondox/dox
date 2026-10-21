// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom.dto.dart';

// **************************************************************************
// DoxDtoGenerator
// **************************************************************************

// ignore_for_file: type=lint

/// The checks, the converter and the JSON Schema of [CreatePost].
const DtoSchema<CreatePost> $CreatePostDto = _$CreatePostDto();

class _$CreatePostDto extends DtoSchema<CreatePost> {
  const _$CreatePostDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => CreatePost;

  @override
  String get name => 'CreatePost';

  @override
  bool get isAsync => true;

  @override
  CreatePost? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // slug: String
    Object? c0;
    c0 = s.string(s.read(input, 'slug'), p, 'slug', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'slug', _m);
    // scores: List<int>
    Object? c1;
    c1 = s.list(s.read(input, 'scores'), p, 'scores', _m);
    if (c1 is List) {
      List<Object> q0 = <Object>[...p, 'scores'];
      List<int> o0 = <int>[];
      for (int i0 = 0; i0 < c1.length; i0++) {
        Object? x0;
        x0 = s.integer(c1[i0], q0, i0, _m);
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as int);
        }
      }
      c1 = o0;
    }
    if (c1 == null) s.required(p, 'scores', _m);
    // handle: String?
    Object? c2;
    c2 = s.string(s.read(input, 'handle'), p, 'handle', _m);
    // handles: List<String>
    Object? c3;
    c3 = s.list(s.read(input, 'handles'), p, 'handles', _m);
    if (c3 is List) {
      List<Object> q0 = <Object>[...p, 'handles'];
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
    if (c3 == null) s.required(p, 'handles', _m);
    if (s.issues.length != e) return null;
    if (c0 is String) {
      if (!(const Slug().check(c0, s.context(p, 'slug', c0)))) {
        s.failRule(const Slug(), p, 'slug', c0, _m);
      }
    }
    if (c1 is List<int>) {
      List<Object> q = <Object>[...p, 'scores'];
      for (int i = 0; i < c1.length; i++) {
        int v = c1[i];
        if (!(const MinValue(5).check(v, s.context(q, i, v)))) {
          s.failRule(const MinValue(5), q, i, v, _m);
        }
      }
    }
    if (s.issues.length != e) return null;
    return CreatePost(
      slug: c0 as String,
      scores: c1 is Undefined ? const <int>[] : c1 as List<int>,
      handle: c2 is Undefined ? null : c2 as String?,
      handles: c3 is Undefined ? const <String>[] : c3 as List<String>,
    );
  }

  @override
  Future<void> checkAsync(CreatePost o, DtoState s, List<Object> p) async {
    {
      String? f = o.handle;
      if (f != null) {
        await s.asyncRule(const NotTaken(), f, p, 'handle', _m);
      }
    }
    {
      List<String> f = o.handles;
      await s.asyncItems(const NotTaken(), f, p, 'handles', _m);
    }
  }

  @override
  CreatePost fromMap(Map<String, dynamic> m) {
    return CreatePost(
      slug: m['slug'] as String,
      scores: m.containsKey('scores')
          ? <int>[
              for (Object? x0 in m['scores'] as List<dynamic>)
                (x0 as num).toInt(),
            ]
          : const <int>[],
      handle: m['handle'] == null ? null : (m['handle'] as String),
      handles: m.containsKey('handles')
          ? <String>[
              for (Object? x0 in m['handles'] as List<dynamic>) x0 as String,
            ]
          : const <String>[],
    );
  }

  @override
  Map<String, dynamic> toMap(CreatePost o) {
    String f0 = o.slug;
    List<int> f1 = o.scores;
    String? f2 = o.handle;
    List<String> f3 = o.handles;
    return <String, dynamic>{
      'slug': f0,
      'scores': f1,
      'handle': f2,
      'handles': f3,
    };
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    Map<String, dynamic> j = <String, dynamic>{
      'type': 'object',
      'title': 'CreatePost',
      'properties': <String, dynamic>{
        'slug': <String, dynamic>{'type': 'string'},
        'scores': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'type': 'integer'},
          'default': <dynamic>[],
        },
        'handle': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'handles': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{'type': 'string'},
          'default': <dynamic>[],
        },
      },
      'required': <dynamic>['slug'],
    };
    JsonSchemaTools.merge(j, <String>[
      'properties',
      'slug',
    ], const Slug().toJsonSchema());
    JsonSchemaTools.merge(j, <String>[
      'properties',
      'scores',
      'items',
    ], const MinValue(5).toJsonSchema());
    JsonSchemaTools.merge(j, <String>[
      'properties',
      'handle',
    ], const NotTaken().toJsonSchema());
    JsonSchemaTools.merge(j, <String>[
      'properties',
      'handles',
      'items',
    ], const NotTaken().toJsonSchema());
    return j;
  }
}
