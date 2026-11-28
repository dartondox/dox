import 'package:dox_core/dox_core.dart';

part 'serialize.g.dart';

/// Puts the JSON writers of this file into the container, like
/// `lib/generated/container.g.dart` does for an app.
void registerSerializeWriters(IocContainer c) {
  c.jsonWriter($ExtraUserDataWriter);
  c.jsonWriter($AddressWriter);
  c.jsonWriter($UserInfoWriter);
  c.jsonWriter($PostSerializerWriter);
  c.jsonWriter($TagLabelWriter);
  c.jsonWriter($LabelOnlyWriter);
  c.jsonWriter($EmptySerializerWriter);
  c.jsonWriter($TagNamesWriter);
  c.jsonWriter($PostTagsWriter);
  c.jsonWriter($ParentSWriter);
  c.jsonWriter($ChildFastSWriter);
  c.jsonWriter($AuthorWriter);
}

enum Level { basic, pro }

/// Stands for a model: it writes its own JSON, and has the same toJson().
class Account implements JsonWritable {
  Account(this.id, this.email);

  final int id;
  final String? email;

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'email': email};

  @override
  void writeJson(JsonWriter writer) {
    writer.startObject();
    writer.key('id');
    writer.integer(id);
    writer.key('email');
    writer.string(email);
    writer.endObject();
  }
}

class Tag {
  Tag(this.name);

  final String? name;
}

class Post {
  Post(this.title, this.tags);

  final String title;
  final List<Tag> tags;
}

class User {
  User({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.score,
    required this.posts,
    this.nick,
    this.account,
    this.lastPost,
  });

  final int id;
  final String name;
  final String? nick;
  final DateTime createdAt;
  final int score;
  final List<Post> posts;
  final Account? account;
  final Post? lastPost;
}

@Serialize()
class Address {
  final String city;
  final String? zipCode;

  const Address({required this.city, this.zipCode});
}

/// A plain class: its public final fields, with snake_case keys.
@Serialize()
class ExtraUserData {
  final int loginCount;
  @Name('seen')
  final DateTime? lastSeen;
  final List<String> roles;
  final Level level;
  final List<Level> levels;
  final Address home;
  final Address? work;
  final List<Address> others;
  final Map<String, int> counts;
  final Map<String, dynamic> meta;
  final double ratio;
  final Account? account;

  // not in the JSON
  static const int version = 1;
  final int _secret = 7;
  int get doubled => loginCount * 2 + _secret;

  ExtraUserData({
    required this.loginCount,
    this.lastSeen,
    required this.roles,
    this.level = Level.basic,
    this.levels = const <Level>[],
    this.home = const Address(city: 'Yangon'),
    this.work,
    this.others = const <Address>[],
    this.counts = const <String, int>{},
    this.meta = const <String, dynamic>{},
    this.ratio = 0.5,
    this.account,
  });

  factory ExtraUserData.of(User user) {
    return ExtraUserData(
      loginCount: user.score,
      lastSeen: user.createdAt,
      roles: <String>['user'],
    );
  }
}

/// A serializer with locals, a model, a plain class, a nested map, a
/// nested serializer and a private tear-off.
@Serialize()
class UserInfo extends Serializer<User> {
  UserInfo(super.data, {this.now});

  final DateTime? now;

  static const String top = 'top';

  String get prefix => '#';

  @override
  Map<String, dynamic> convert(User m) {
    DateTime base = now ?? DateTime.utc(2024);
    bool recent = m.createdAt.isAfter(base.subtract(const Duration(days: 2)));
    String label = m.score > 10 ? top : 'normal';
    return <String, dynamic>{
      'data': m.account,
      'extra': ExtraUserData.of(m),
      'active': recent,
      'label': label,
      'name': '$prefix${m.name}',
      'nick': m.nick ?? m.name,
      'tags': m.posts.expand((Post p) => p.tags).map(_tagName).toList(),
      'rating': <String, dynamic>{
        'score': m.score,
        'count': m.posts.length,
        'deep': <String, dynamic>{'half': m.score / 2, 'at': m.createdAt},
      },
      'posts': PostSerializer(m.posts),
      'last': PostSerializer(m.lastPost),
      'first': m.posts.isEmpty ? null : PostSerializer(m.posts.first),
      'id': this.idOf(m), // ignore: unnecessary_this
    };
  }

  String? _tagName(Tag t) => t.name;

  int idOf(User m) => m.id;
}

@Serialize()
class PostSerializer extends Serializer<Post> {
  PostSerializer(super.data);

  @override
  Map<String, dynamic> convert(Post m) {
    return <String, dynamic>{
      'title': m.title,
      'tags': <String?>[for (Tag t in m.tags) t.name],
      'labels': TagLabel(m.tags),
    };
  }
}

/// a serializer that another one writes with no object
@Serialize()
class TagLabel extends Serializer<Tag> {
  TagLabel(super.data);

  @override
  Map<String, dynamic> convert(Tag m) => <String, dynamic>{'tag': m.name};
}

/// It uses a member, so a value `LabelOnly(x)` makes the object.
@Serialize()
class LabelOnly extends Serializer<Tag> {
  LabelOnly(super.data, this.mark);

  final String mark;

  @override
  Map<String, dynamic> convert(Tag m) {
    return <String, dynamic>{'label': '$mark${m.name}'};
  }
}

/// The template of `dox make:serializer`.
@Serialize()
class EmptySerializer extends Serializer<Post> {
  EmptySerializer(super.data);

  @override
  Map<String, dynamic> convert(Post m) {
    return <String, dynamic>{};
  }
}

// ---------------------------------------------------------------------------
// Shapes that keep the map of toJson(): no JSON writer.
// ---------------------------------------------------------------------------

@Serialize()
class WithIf extends Serializer<Post> {
  WithIf(super.data);

  @override
  Map<String, dynamic> convert(Post m) {
    return <String, dynamic>{
      'title': m.title,
      if (m.tags.isNotEmpty) 'tag': m.tags.first.name,
    };
  }
}

@Serialize()
class WithFor extends Serializer<Post> {
  WithFor(super.data);

  @override
  Map<String, dynamic> convert(Post m) {
    return <String, dynamic>{for (Tag t in m.tags) 'tag_${t.name}': true};
  }
}

@Serialize()
class WithSpread extends Serializer<Post> {
  WithSpread(super.data);

  @override
  Map<String, dynamic> convert(Post m) {
    return <String, dynamic>{
      'title': m.title,
      ...<String, dynamic>{'more': 1},
    };
  }
}

@Serialize()
class WithKey extends Serializer<Post> {
  WithKey(super.data);

  @override
  Map<String, dynamic> convert(Post m) {
    return <String, dynamic>{m.title: 1};
  }
}

@Serialize()
class WithIfStatement extends Serializer<Post> {
  WithIfStatement(super.data);

  @override
  Map<String, dynamic> convert(Post m) {
    if (m.tags.isEmpty) {
      return <String, dynamic>{'title': m.title};
    }
    return <String, dynamic>{'title': m.title, 'tags': m.tags.length};
  }
}

@Serialize()
class WithMapVariable extends Serializer<Post> {
  WithMapVariable(super.data);

  @override
  Map<String, dynamic> convert(Post m) {
    Map<String, dynamic> map = <String, dynamic>{'title': m.title};
    return map;
  }
}

/// A plain class with its own toJson() keeps it.
@Serialize()
class OwnJson {
  final int id;

  const OwnJson(this.id);

  Map<String, dynamic> toJson() => <String, dynamic>{'my_id': id};
}

// ---------------------------------------------------------------------------
// Review cases
// ---------------------------------------------------------------------------

/// Not @Serialize: its constructor changes the data.
class BaseTags<T> extends Serializer<T> {
  BaseTags(dynamic data) : super(data ?? <T>[]);
}

@Serialize()
class TagNames extends BaseTags<Tag> {
  TagNames(super.data);

  @override
  Map<String, dynamic> convert(Tag m) => <String, dynamic>{'n': m.name};
}

@Serialize()
class PostTags extends Serializer<Post> {
  PostTags(super.data);

  @override
  Map<String, dynamic> convert(Post m) {
    return <String, dynamic>{
      'tags': TagNames(m.tags.isEmpty ? null : m.tags.first),
      'author': m.title == 'special'
          ? SpecialAuthor('b', 'gold')
          : const Author('a'),
    };
  }
}

@Serialize()
class ParentS extends Serializer<Tag> {
  ParentS(super.data);

  @override
  Map<String, dynamic> convert(Tag m) => <String, dynamic>{'parent': m.name};
}

/// no @Serialize: the map of its toJson()
class ChildS extends ParentS {
  ChildS(super.data);

  @override
  Map<String, dynamic> convert(Tag m) => <String, dynamic>{'child': m.name};
}

/// @Serialize, but a shape with no writer
@Serialize()
class ChildIfS extends ParentS {
  ChildIfS(super.data);

  @override
  Map<String, dynamic> convert(Tag m) {
    return <String, dynamic>{if (m.name != null) 'child_if': m.name};
  }
}

/// @Serialize with its own writer
@Serialize()
class ChildFastS extends ParentS {
  ChildFastS(super.data);

  @override
  Map<String, dynamic> convert(Tag m) => <String, dynamic>{'fast': m.name};
}

@Serialize()
class Author {
  final String name;

  const Author(this.name);
}

/// not @Serialize: its toJson() gives its JSON
class SpecialAuthor extends Author {
  SpecialAuthor(super.name, this.badge);

  final String badge;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'badge': badge,
  };
}
