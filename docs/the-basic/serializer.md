---
icon: lucide/braces
---

# Serializer

A serializer sets the JSON shape of a response: which keys the client gets, their names and their values.

It works with any Dart type: a model, a plain class or a map. A controller can also return a model, a map or a list as it is. See [Response](response.md#return-a-value). To only hide some model fields, use [`hidden`](../database/model/index.md#hide-fields).

## Create a serializer

Make a serializer with the CLI. It writes `lib/app/serializers/blog.serializer.dart`, for the model with the same name:

```bash
dox make:serializer Blog
```

## Writing a serializer

Extend `Serializer<T>` and write `convert`. It gets one value and gives one JSON object:

```dart title="lib/app/serializers/blog.serializer.dart"
import 'package:dox_core/dox_core.dart';

import 'package:my_app/app/models/blog/blog.model.dart';

class BlogSerializer extends Serializer<Blog> {
  BlogSerializer(super.data);

  @override
  Map<String, dynamic> convert(Blog m) {
    return <String, dynamic>{
      'uid': m.id,
      'title_en': m.title,
    };
  }
}
```

Return the serializer from a controller, with one model or a list:

```dart title="lib/app/http/controllers/blog.controller.dart"
class BlogController {
  Future<BlogSerializer> index(DoxRequest req) async {
    List<Blog> blogs = await Blog().all();
    return BlogSerializer(blogs); // a list
  }

  Future<BlogSerializer> show(DoxRequest req, String id) async {
    Blog? blog = await Blog().find(id);
    return BlogSerializer(blog); // one model
  }
}
```

The response of `show`:

```json
{
  "uid": 1,
  "title_en": "This is title"
}
```

This is what the client gets for each input:

| You give | The client gets |
| --- | --- |
| one value of type `T` | one JSON object |
| a `List<T>` | a JSON list (`[]` when the list is empty) |
| null, or any other type | null |

A `List<dynamic>`, like a list from `jsonDecode`, gives null. Call `.cast<T>()` first. See [JSON from another API](#json-from-another-api).

### Getting the JSON

`toJson()` gives the map, the list or null, for use in other code:

```dart
dynamic json = BlogSerializer(blogs).toJson();
```

## Fast JSON with `@Serialize()`

A serializer makes a map for each value. Then the JSON encoder reads the map. `@Serialize()` removes the map. `dox_builder` writes code that writes the JSON bytes directly. The JSON does not change.

### Make a serializer fast

Add `@Serialize()`, the `part` line and `with _$Name` to the serializer. Then run `dart run build_runner build`:

```dart title="lib/app/serializers/user_info.serializer.dart"
import 'package:dox_core/dox_core.dart';

part 'user_info.serializer.g.dart';

@Serialize()
class UserInfo extends Serializer<User> with _$UserInfo {
  UserInfo(super.data);

  @override
  Map<String, dynamic> convert(User m) {
    bool recent = m.createdAt!.isAfter(DateTime.now().subtract(const Duration(days: 2)));
    return <String, dynamic>{
      'data': m, // a model
      'extra': ExtraUserData.of(m), // a plain @Serialize() class
      'active': recent,
      'label': m.score > 10 ? 'top' : 'normal',
      'tags': m.tags.map(_tagName).toList(),
      'rating': <String, dynamic>{'score': m.score, 'count': m.count},
      'posts': PostSerializer(m.posts), // one post or a list of posts
    };
  }

  String? _tagName(Tag t) => t.name;
}
```

`convert()` must have this shape:

- Zero or more local variables.
- Then one `return` of a map literal.
- Each key is a constant string, like `'name'`.
- A value can be any expression. A value can also be a map literal with the same rules.

The generated code runs each local variable and each value one time, in the same order as `convert()`.

Put a nested serializer in the map as it is, like `PostSerializer(m.posts)`. Do not call `toJson()` on it. Then the nested serializer is fast too.

`with _$Name` is optional. Without it, the serializer is also fast, but Dox finds its writer at run time. That takes approximately 30 ns more for each response. `lib/generated/container.g.dart` gives the writers to Dox, so set `AppConfig(container: registerContainer)`.

### Shapes that keep the map

For some shapes, the code can not be written with no guess. Then `dox_builder` writes no fast code, and the build log shows a warning with the reason. The serializer still works, with its map, as before.

These shapes keep the map:

- A collection `if`, `for` or spread (`...`) in a map.
- A key that is not a constant string, like `m.title: 1`.
- An `if` statement, a loop or any other statement that is not a local variable.
- More than one `return`.
- A `return` of a value that is not a map literal, like a variable.
- `super` in `convert()`.
- A serializer with its own `toJson()`.

A class that extends a `@Serialize()` serializer must also have `@Serialize()` and `with _$Name`. If it does not, its JSON comes from the `convert()` of the parent class. The build log shows a warning for this.

### Write a plain class as JSON

Add `@Serialize()` and the `part` line to a plain class. Dox then writes its public final fields as JSON. You do not write a serializer:

```dart title="lib/app/serializers/extra_user_data.dart"
import 'package:dox_core/dox_core.dart';

part 'extra_user_data.g.dart';

@Serialize()
class ExtraUserData {
  final int loginCount; // key "login_count"
  @Name('seen')
  final DateTime? lastSeen; // key "seen"
  final List<String> roles;

  const ExtraUserData({required this.loginCount, this.lastSeen, required this.roles});
}
```

The keys and the values follow the same rules as a [DTO in a response](response.md):

- A key is the field name in snake_case. `@Name` sets a different key.
- The fields are in the order of the class.
- A `DateTime` becomes ISO 8601 text.
- An enum becomes its name.
- A nested `@Serialize()` class, a list and a map are written too.

A controller can return the class, or a list of it. A serializer can use it as a value. `JSON.bytes()` and `JSON.stringify()` take it too.

A plain class with its own `toJson()` keeps `toJson()`. An abstract class and a generic class get no fast code.

`lib/generated/container.g.dart` gives the writers to Dox, so set `AppConfig(container: registerContainer)`. Without it, a plain class in a response is an error.

### Use the encoder of the Dart SDK

`CoreFlags(sdkJsonEncoder: true)` makes Dox use the JSON encoder of the Dart SDK. With this flag, a serializer uses its map again, and a plain class uses the generated function `$NameToMap`. The JSON is the same.

## Examples with models

### Change values

Format dates, join fields and add new keys:

```dart title="lib/app/serializers/user.serializer.dart"
class UserSerializer extends Serializer<User> {
  UserSerializer(super.data);

  @override
  Map<String, dynamic> convert(User m) {
    return <String, dynamic>{
      'id': m.id,
      'name': '${m.firstName} ${m.lastName}',
      'is_active': m.status == 'active',
      'joined_at': m.createdAt?.toIso8601String(),
    };
  }
}
```

### A serializer inside a serializer

Use the serializer of a relation inside the other one:

```dart title="lib/app/serializers/comment.serializer.dart"
class CommentSerializer extends Serializer<Comment> {
  CommentSerializer(super.data);

  @override
  Map<String, dynamic> convert(Comment m) {
    return <String, dynamic>{
      'id': m.id,
      'content': m.content,
      'user': UserSerializer(m.user).toJson(), // null when there is no user
    };
  }
}
```

Load the relation first, with [`preload`](../database/model/relationship/belongs-to.md#loading-the-relation):

```dart
Future<CommentSerializer> index(DoxRequest req) async {
  List<Comment> comments = await Comment().preload('user').all();
  return CommentSerializer(comments);
}
```

### With pagination

Put the serializer output in place of `data` of the page:

```dart
Future<Map<String, dynamic>> index(ListUsers query) async {
  Pagination<User> page = await User()
      .orderBy('id', 'desc')
      .paginate(currentPage: query.page, perPage: query.perPage);
  return <String, dynamic>{
    ...page.toJson(),
    'data': UserSerializer(page.data).toJson(),
  };
}
```

See [Pagination](../guides/pagination.md).

## Examples without models

### A plain Dart class

A serializer for a plain class works the same way:

```dart title="lib/app/serializers/weather.serializer.dart"
class Weather {
  final String city;
  final double celsius;

  Weather(this.city, this.celsius);
}

class WeatherSerializer extends Serializer<Weather> {
  WeatherSerializer(super.data);

  @override
  Map<String, dynamic> convert(Weather m) {
    return <String, dynamic>{
      'city': m.city,
      'celsius': m.celsius,
      'fahrenheit': m.celsius * 9 / 5 + 32,
    };
  }
}
```

### Rows from the query builder

`QueryBuilder.table(...)` gives rows as maps. Use `Serializer<Map<String, dynamic>>` to pick and rename the keys:

```dart title="lib/app/serializers/sales_report.serializer.dart"
class SalesReportSerializer extends Serializer<Map<String, dynamic>> {
  SalesReportSerializer(super.data);

  @override
  Map<String, dynamic> convert(Map<String, dynamic> m) {
    return <String, dynamic>{
      'product': m['name'],
      'sold': m['total'],
    };
  }
}
```

```dart
Future<SalesReportSerializer> report(DoxRequest req) async {
  List<Map<String, dynamic>> rows = await QueryBuilder.table('orders')
      .selectRaw('name, count(*) as total')
      .groupBy('name')
      .get();
  return SalesReportSerializer(rows);
}
```

### JSON from another API

Cast the list to the type of the serializer first:

```dart
Future<SalesReportSerializer> remote(DoxRequest req) async {
  String body = await fetchReport(); // your HTTP call
  List<dynamic> rows = jsonDecode(body);
  return SalesReportSerializer(rows.cast<Map<String, dynamic>>());
}
```

## Next steps

- [Response](response.md): other values a controller can return.
- [CLI: `dox make:serializer`](../reference/cli.md#dox-makeserializer): the make command.
