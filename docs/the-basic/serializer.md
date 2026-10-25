# Serializer

A serializer sets the JSON shape of a response: which keys the client gets, their names and their values.
It works with any Dart type: a model, a plain class, or a map.

!!! tip
    You do not always need a serializer.
    A controller can return a model, a `Map` or a `List` as it is. See [Response](response.md#return-a-value).
    To only hide some model fields, use [`hidden`](../database/model/index.md#hide-fields).

## Create a serializer

```bash
dox create:serializer Blog
```

This makes `lib/app/http/serializers/blog.serializer.dart`.
The file is for a model with the same name. Change the type to use it for something else.

## How it works

Extend `Serializer<T>` and write `convert`.
`convert` gets one value of type `T` and gives back one JSON object.

```dart title="lib/app/http/serializers/blog.serializer.dart"
import 'package:dox_core/dox_core.dart';

import '../../../app/models/blog/blog.model.dart';

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

Return the serializer from a controller. Dox sends its `toJson()`.

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

What you give, and what the client gets:

| You give | The client gets |
| --- | --- |
| one value of type `T` | one JSON object |
| a `List<T>` | a JSON list (`[]` when the list is empty) |
| `null` (for example, `find` found nothing) | `null` |
| any other type | `null` |

!!! warning "The list type must be `List<T>`"
    A `List<dynamic>` is not a `List<T>`, so the response is `null`.
    This happens with a list from `jsonDecode`. Call `.cast<T>()` first.
    See [JSON from another API](#json-from-another-api).

## Examples with models

### Change values

`convert` is plain Dart. You can format dates, join fields and add new keys.

```dart title="lib/app/http/serializers/user.serializer.dart"
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

Use one serializer for a relation inside another.
Load the relation first, for example with [`preload`](../database/model/relationship/belongs-to.md#load-it).

```dart title="lib/app/http/serializers/comment.serializer.dart"
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

```dart
Future<CommentSerializer> index(DoxRequest req) async {
  List<Comment> comments = await Comment().preload('user').all();
  return CommentSerializer(comments);
}
```

### With pagination

`page.data` is a `List<User>`. Put the serializer output in place of `data`.

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

See [Pagination](../guides/pagination.md) for the full example.

## Examples without models

`T` can be any type. You do not need the ORM.

### A plain Dart class

```dart title="lib/app/http/serializers/weather.serializer.dart"
import 'package:dox_core/dox_core.dart';

class Weather {
  final String city;
  final double celsius;

  Weather(this.city, this.celsius);
}

class WeatherSerializer extends Serializer<Weather> {
  WeatherSerializer(super.data);

  @override
  Map<String, dynamic> convert(Weather w) {
    return <String, dynamic>{
      'city': w.city,
      'celsius': w.celsius,
      'fahrenheit': w.celsius * 9 / 5 + 32,
    };
  }
}
```

```dart
WeatherSerializer today(DoxRequest req) {
  return WeatherSerializer(<Weather>[Weather('Yangon', 30)]);
}
```

### Rows from the query builder

`QueryBuilder.table(...)` gives rows as maps, not models.
Use `Serializer<Map<String, dynamic>>` to pick and rename the keys.

```dart title="lib/app/http/serializers/sales_report.serializer.dart"
class SalesReportSerializer extends Serializer<Map<String, dynamic>> {
  SalesReportSerializer(super.data);

  @override
  Map<String, dynamic> convert(Map<String, dynamic> row) {
    return <String, dynamic>{
      'product': row['name'],
      'sold': row['total'],
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

`jsonDecode` gives a `List<dynamic>`. Cast it to the type of the serializer first.

```dart
Future<SalesReportSerializer> remote(DoxRequest req) async {
  String body = await fetchReport(); // your HTTP call
  List<dynamic> rows = jsonDecode(body);
  return SalesReportSerializer(rows.cast<Map<String, dynamic>>());
}
```

## See also

- [CLI: `dox create:serializer`](../reference/cli.md#dox-createserializer)
