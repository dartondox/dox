// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom.dto.dart';

// **************************************************************************
// DoxDtoGenerator
// **************************************************************************

// ignore_for_file: type=lint

/// The checks, the converter and the JSON Schema of [CreatePost].
const DtoSchema<CreatePost> $CreatePostDto = _$CreatePostDto();

class _$CreatePostDto extends DtoSchema<CreatePost>
    implements JsonObjectWriter {
  const _$CreatePostDto();

  static const Map<String, String> _messages = <String, String>{};

  @override
  Type get type => CreatePost;

  @override
  String get name => 'CreatePost';

  @override
  bool get usesRequiredWhen => false;

  @override
  bool get isAsync => true;

  @override
  CreatePost? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // slug: String
    Object? slug = state.string(
      state.read(input, 'slug'),
      path,
      'slug',
      _messages,
    );
    if (slug == null || slug is Undefined)
      state.required(path, 'slug', _messages);
    // scores: List<int>
    Object? scores = state.list(
      state.read(input, 'scores'),
      path,
      'scores',
      _messages,
    );
    if (scores is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'scores'];
      List<int> o0 = <int>[];
      for (int i0 = 0; i0 < scores.length; i0++) {
        Object? x0 = state.integer(scores[i0], q0, i0, _messages);
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as int);
        }
      }
      scores = state.issues.length != b0 ? invalid : o0;
    }
    if (scores == null) state.required(path, 'scores', _messages);
    // handle: String?
    Object? handle = state.string(
      state.read(input, 'handle'),
      path,
      'handle',
      _messages,
    );
    // handles: List<String>
    Object? handles = state.list(
      state.read(input, 'handles'),
      path,
      'handles',
      _messages,
    );
    if (handles is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'handles'];
      List<String> o0 = <String>[];
      for (int i0 = 0; i0 < handles.length; i0++) {
        Object? x0 = state.string(handles[i0], q0, i0, _messages);
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as String);
        }
      }
      handles = state.issues.length != b0 ? invalid : o0;
    }
    if (handles == null) state.required(path, 'handles', _messages);
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (slug is String) {
      if (!(const Slug().check(slug, state.context(path, 'slug', slug)))) {
        state.failRule(const Slug(), path, 'slug', slug, _messages);
      }
    }
    if (scores is List<int>) {
      List<Object> q = <Object>[...path, 'scores'];
      for (int i = 0; i < scores.length; i++) {
        int v = scores[i];
        if (!(const MinValue(5).check(v, state.context(q, i, v)))) {
          state.failRule(const MinValue(5), q, i, v, _messages);
        }
      }
    }
    if (state.issues.length != issuesBefore) return null;
    return CreatePost(
      slug: slug as String,
      scores: scores is Undefined ? const <int>[] : scores as List<int>,
      handle: handle is Undefined ? null : handle as String?,
      handles: handles is Undefined
          ? const <String>[]
          : handles as List<String>,
    );
  }

  @override
  Future<void> checkAsync(
    CreatePost dto,
    DtoState state,
    List<Object> path,
  ) async {
    {
      String? value = dto.handle;
      if (value != null) {
        await state.asyncRule(
          const NotTaken(),
          value,
          path,
          'handle',
          _messages,
        );
      }
    }
    {
      List<String> value = dto.handles;
      await state.asyncItems(
        const NotTaken(),
        value,
        path,
        'handles',
        _messages,
      );
    }
  }

  @override
  CreatePost fromMap(Map<String, dynamic> map) {
    return CreatePost(
      slug: map['slug'] as String,
      scores: map.containsKey('scores')
          ? <int>[
              for (Object? x0 in map['scores'] as List<dynamic>)
                (x0 as num).toInt(),
            ]
          : const <int>[],
      handle: map['handle'] == null ? null : (map['handle'] as String),
      handles: map.containsKey('handles')
          ? <String>[
              for (Object? x0 in map['handles'] as List<dynamic>) x0 as String,
            ]
          : const <String>[],
    );
  }

  @override
  Map<String, dynamic> toMap(CreatePost dto) {
    return <String, dynamic>{
      'slug': dto.slug,
      'scores': dto.scores,
      'handle': dto.handle,
      'handles': dto.handles,
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as CreatePost));

  @override
  Map<String, dynamic> toJsonSchema() {
    Map<String, dynamic> schema = <String, dynamic>{
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
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'slug',
    ], const Slug().toJsonSchema());
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'scores',
      'items',
    ], const MinValue(5).toJsonSchema());
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'handle',
    ], const NotTaken().toJsonSchema());
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'handles',
      'items',
    ], const NotTaken().toJsonSchema());
    return schema;
  }
}

/// The checks, the converter and the JSON Schema of [ListPosts].
const DtoSchema<ListPosts> $ListPostsDto = _$ListPostsDto();

class _$ListPostsDto extends DtoSchema<ListPosts> implements JsonObjectWriter {
  const _$ListPostsDto();

  static const Map<String, String> _messages = <String, String>{};

  @override
  Type get type => ListPosts;

  @override
  String get name => 'ListPosts';

  @override
  bool get usesRequiredWhen => false;

  @override
  bool get isAsync => true;

  @override
  ListPosts? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // page: int
    int pageIssuesBefore = state.issues.length;
    Object? page = state.integer(
      state.read(input, 'page', emptyToNull: true),
      path,
      'page',
      _messages,
    );
    if (page == null) state.required(path, 'page', _messages);
    if (state.dropIssuesAfter(pageIssuesBefore)) page = undefined;
    // days: Maybe<int>
    int daysIssuesBefore = state.issues.length;
    Object? days = state.integer(
      state.read(input, 'days', emptyToNull: true),
      path,
      'days',
      _messages,
    );
    if (days == null || state.sentEmpty(days, input, 'days'))
      state.required(path, 'days', _messages);
    if (state.dropIssuesAfter(daysIssuesBefore)) days = undefined;
    // handle: String?
    int handleIssuesBefore = state.issues.length;
    Object? handle = state.string(
      state.read(input, 'handle', emptyToNull: true),
      path,
      'handle',
      _messages,
    );
    if (state.dropIssuesAfter(handleIssuesBefore)) handle = undefined;
    // color: String?
    Object? color = state.string(
      state.read(input, 'color', emptyToNull: true),
      path,
      'color',
      _messages,
    );
    // note: String?
    Object? note = state.string(
      state.read(input, 'note', emptyToNull: true),
      path,
      'note',
      _messages,
    );
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    int pageIssuesBeforeRules = state.issues.length;
    if (page is int) {
      if (!(const MinValue(1).check(page, state.context(path, 'page', page)))) {
        state.failRule(const MinValue(1), path, 'page', page, _messages);
      }
    }
    if (state.dropIssuesAfter(pageIssuesBeforeRules)) page = undefined;
    if (color is String) {
      if (!(const HexColor(short: true)
          .check(color, state.context(path, 'color', color)))) {
        state.failRule(
          const HexColor(short: true),
          path,
          'color',
          color,
          _messages,
        );
      }
    }
    if (state.issues.length != issuesBefore) return null;
    return ListPosts(
      page: page is Undefined ? 1 : page as int,
      days: days is Undefined
          ? const Maybe<int>.missing()
          : Maybe<int>(days as int),
      handle: handle is Undefined ? null : handle as String?,
      color: color is Undefined ? null : color as String?,
      note: note is Undefined ? null : note as String?,
    );
  }

  @override
  Future<void> checkAsync(
    ListPosts dto,
    DtoState state,
    List<Object> path,
  ) async {
    {
      String? value = dto.handle;
      if (value != null) {
        await state.asyncRule(
          const NotTaken(),
          value,
          path,
          'handle',
          _messages,
        );
      }
    }
  }

  @override
  ListPosts fromMap(Map<String, dynamic> map) {
    return ListPosts(
      page: map.containsKey('page') ? (map['page'] as num).toInt() : 1,
      days: map.containsKey('days')
          ? Maybe<int>((map['days'] as num).toInt())
          : const Maybe<int>.missing(),
      handle: map['handle'] == null ? null : (map['handle'] as String),
      color: map['color'] == null ? null : (map['color'] as String),
      note: map['note'] == null ? null : (map['note'] as String),
    );
  }

  @override
  Map<String, dynamic> toMap(ListPosts dto) {
    return <String, dynamic>{
      'page': dto.page,
      if (dto.days case Maybe<int>(isPresent: true, value: int days))
        'days': days,
      'handle': dto.handle,
      'color': dto.color,
      'note': dto.note,
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      writer.value(toMap(object as ListPosts));

  @override
  Map<String, dynamic> toJsonSchema() {
    Map<String, dynamic> schema = <String, dynamic>{
      'type': 'object',
      'title': 'ListPosts',
      'properties': <String, dynamic>{
        'page': <String, dynamic>{'type': 'integer', 'default': 1},
        'days': <String, dynamic>{'type': 'integer'},
        'handle': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
          'description': 'an async rule still fails with @OrDefault',
        },
        'color': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
        'note': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
      },
    };
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'page',
    ], const MinValue(1).toJsonSchema());
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'handle',
    ], const NotTaken().toJsonSchema());
    JsonSchemaTools.merge(schema, <String>[
      'properties',
      'color',
    ], const HexColor(short: true).toJsonSchema());
    return schema;
  }
}
