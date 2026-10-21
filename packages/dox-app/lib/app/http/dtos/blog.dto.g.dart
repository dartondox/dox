// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blog.dto.dart';

// **************************************************************************
// DoxDtoGenerator
// **************************************************************************

// ignore_for_file: type=lint

/// The checks, the converter and the JSON Schema of [ListBlogs].
const DtoSchema<ListBlogs> $ListBlogsDto = _$ListBlogsDto();

class _$ListBlogsDto extends DtoSchema<ListBlogs> {
  const _$ListBlogsDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => ListBlogs;

  @override
  String get name => 'ListBlogs';

  @override
  ListBlogs? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // page: int
    Object? c0;
    c0 = s.integer(s.read(input, 'page'), p, 'page', _m);
    if (c0 == null) s.required(p, 'page', _m);
    // limit: int
    Object? c1;
    c1 = s.integer(s.read(input, 'limit'), p, 'limit', _m);
    if (c1 == null) s.required(p, 'limit', _m);
    // withTrashed: bool
    Object? c2;
    c2 = s.boolean(s.read(input, 'with_trashed'), p, 'with_trashed', _m);
    if (c2 == null) s.required(p, 'with_trashed', _m);
    if (s.issues.length != e) return null;
    if (c0 is int) {
      if (!(c0 >= 1)) {
        s.fail(
          p,
          'page',
          IssueCodes.min,
          DefaultMessages.min,
          c0,
          params: const <String, Object?>{'min': 1},
          messages: _m,
        );
      }
    }
    if (c1 is int) {
      if (!(c1 >= 1 && c1 <= 100)) {
        s.fail(
          p,
          'limit',
          IssueCodes.between,
          DefaultMessages.between,
          c1,
          params: const <String, Object?>{'min': 1, 'max': 100},
          messages: _m,
        );
      }
    }
    if (s.issues.length != e) return null;
    return ListBlogs(
      page: c0 is Undefined ? 1 : c0 as int,
      limit: c1 is Undefined ? 20 : c1 as int,
      withTrashed: c2 is Undefined ? false : c2 as bool,
    );
  }

  @override
  ListBlogs fromMap(Map<String, dynamic> m) {
    return ListBlogs(
      page: m.containsKey('page') ? (m['page'] as num).toInt() : 1,
      limit: m.containsKey('limit') ? (m['limit'] as num).toInt() : 20,
      withTrashed: m.containsKey('with_trashed')
          ? m['with_trashed'] as bool
          : false,
    );
  }

  @override
  Map<String, dynamic> toMap(ListBlogs o) {
    int f0 = o.page;
    int f1 = o.limit;
    bool f2 = o.withTrashed;
    return <String, dynamic>{'page': f0, 'limit': f1, 'with_trashed': f2};
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'ListBlogs',
      'properties': <String, dynamic>{
        'page': <String, dynamic>{
          'type': 'integer',
          'minimum': 1,
          'description': 'Page number, from 1.',
          'default': 1,
        },
        'limit': <String, dynamic>{
          'type': 'integer',
          'minimum': 1,
          'maximum': 100,
          'description': 'Blogs per page.',
          'default': 20,
        },
        'with_trashed': <String, dynamic>{
          'type': 'boolean',
          'description': 'Also list deleted blogs.',
          'default': false,
        },
      },
    };
  }
}

/// The checks, the converter and the JSON Schema of [SaveBlog].
const DtoSchema<SaveBlog> $SaveBlogDto = _$SaveBlogDto();

class _$SaveBlogDto extends DtoSchema<SaveBlog> {
  const _$SaveBlogDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => SaveBlog;

  @override
  String get name => 'SaveBlog';

  @override
  SaveBlog? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // title: String
    Object? c0;
    c0 = s.string(s.read(input, 'title'), p, 'title', _m, trim: true);
    if (c0 == null || c0 is Undefined) s.required(p, 'title', _m);
    // description: String
    Object? c1;
    c1 = s.string(
      s.read(input, 'description'),
      p,
      'description',
      _m,
      trim: true,
    );
    if (c1 == null || c1 is Undefined) s.required(p, 'description', _m);
    if (s.issues.length != e) return null;
    if (c0 is String) {
      if (!(c0.runes.length <= 255)) {
        s.fail(
          p,
          'title',
          IssueCodes.maxLength,
          DefaultMessages.maxLength,
          c0,
          params: const <String, Object?>{'max': 255},
          messages: _m,
        );
      }
    }
    if (s.issues.length != e) return null;
    return SaveBlog(title: c0 as String, description: c1 as String);
  }

  @override
  SaveBlog fromMap(Map<String, dynamic> m) {
    return SaveBlog(
      title: m['title'] as String,
      description: m['description'] as String,
    );
  }

  @override
  Map<String, dynamic> toMap(SaveBlog o) {
    String f0 = o.title;
    String f1 = o.description;
    return <String, dynamic>{'title': f0, 'description': f1};
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'SaveBlog',
      'properties': <String, dynamic>{
        'title': <String, dynamic>{'type': 'string', 'maxLength': 255},
        'description': <String, dynamic>{'type': 'string'},
      },
      'required': <dynamic>['title', 'description'],
    };
  }
}
