# Serializer

A serializer changes how a model looks in the HTTP response.
Use it when the JSON keys or values must be different from the model columns.

!!! tip
    You do not always need a serializer.
    A model can be returned from a controller as it is. Dox sends `toJson()`.
    To only hide fields, use [`hidden`](index.md#hide-fields).

## Create a serializer

```bash
dox create:serializer Blog
```

This makes `lib/app/http/serializers/blog.serializer.dart`.

## Use

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

- `convert` runs once for each model.
- Give a list, and the response is a JSON list.
  Give one model, and the response is one JSON object.
- Give `null` (for example, `find` found nothing), and the response body is `null`.
- The type in `Serializer<Blog>` must be the model type. Other values are ignored.
