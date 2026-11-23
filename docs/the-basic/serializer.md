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
