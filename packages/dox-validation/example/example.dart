import 'package:dox_validation/dox_validation.dart';

/// A reusable rule: text must be a URL slug.
class SlugRule extends Rule<String> {
  SlugRule({super.message});

  @override
  String get name {
    return 'slug';
  }

  @override
  String get defaultMessage {
    return 'The {field} must be a slug';
  }

  @override
  bool check(String value, RuleContext context) {
    return RegExp(r'^[a-z0-9-]+$').hasMatch(value);
  }
}

/// Adds `.slug()` to every string schema.
extension SlugMethods on StringSchema {
  StringSchema slug({String? message}) {
    return use(SlugRule(message: message));
  }
}

void main() {
  ObjectSchema createPost = v.object(<String, Schema<Object?>>{
    'title': v.string().trim().min(3).max(100).describe('Post title'),
    'slug': v.string().slug(),
    'views': v.coerce.int().nonNegative().defaultTo(0),
    'tags': v.list(v.string()).max(5).optional(),
    'status': v.enumOf<String>(<String>['draft', 'published']),
  });

  ParseResult<Map<String, dynamic>> ok = createPost.safeParse(<String, dynamic>{
    'title': '  Hello Dox  ',
    'slug': 'hello-dox',
    'views': '12',
    'status': 'draft',
  });
  print(ok.value);

  ParseResult<Map<String, dynamic>> bad = createPost.safeParse(
    <String, dynamic>{'title': 'Hi', 'slug': 'Hello Dox', 'status': 'archived'},
  );
  print(bad.errors);

  ObjectSchema legacy = v.fromRules(<String, String>{
    'email': 'required|email|max:255',
    'age': 'nullable|integer|min:18',
  });
  print(legacy.safeParse(<String, dynamic>{'email': 'x'}).errors);

  print(createPost.toJsonSchema());
}
