# Validation

`req.validate()` checks the request data with rule strings, like `'required|email'`.
When a rule fails, Dox answers `422` with the errors, like `{"email": "The email is required"}`.

It runs on [`dox_validation`](../packages/validation.md), which is built into `dox_core`.
The rule strings become a schema once (`v.fromRules()`), and Dox keeps it for the next request.

=== "Validation"

    ```dart
    class BlogController {
        create(DoxRequest req) {
            req.validate({
                'title': 'required|string|alpha',
                'body' : 'required|string',
                'status' : 'required|in:active,draft',
            });

            ....
        }
    }
    ```

=== "Request body"

    ```json
    {
        "title" : "Dartondox",
        "body" : "A perfect solution for your web backend development with dart, a comprehensive and versatile framework that offers a wide range of features to help you build powerful and scalable web applications.",
        "status" : "active",
    }
    ```

!!! tip
    Multiple rules can be separated by a vertical bar, represented as " | ".

## Validated data

`validate()` returns only the fields that have rules. The values are not changed.

```dart
Map<String, dynamic> data = req.validate({
    'title': 'required|string',
    'body': 'required',
});
```

## Database rules: `unique` and `exists`

These rules read the database, so they are async. Use `validateAsync`:

```dart
Map<String, dynamic> data = await req.validateAsync({
    'email': 'required|email|unique:users,email',
    'category_id': 'required|exists:categories,id',
});
```

- `unique:table,column`: no row has this value. `column` defaults to the field name.
- `unique:users,email,5`: ignore the row with `id = 5` (for an update). `unique:users,email,5,user_id` uses another id column.
- `exists:table,column`: a row with this value must exist.

They use the default connection of `dox_orm`. `SqlQueryBuilder.initialize()` adds them, so they work once the ORM service runs.
`req.validate()` with an async rule throws an error that tells you to use `validateAsync`.
A [form request](request.md#custom-form-request) always runs async rules.

## Typed schemas

`validateSchema` takes a `dox_validation` schema and returns its typed output.
Use `v.coerce` for query strings and form data, because they are text.

```dart
Map<String, dynamic> data = await req.validateSchema(v.object(<String, Schema<Object?>>{
    'name': v.string().trim().min(3),
    'age': v.coerce.int().min(18),
    'tags': v.list(v.string()).max(5).optional(),
}));
int age = data['age']; // an int, not '18'
```

`v`, `Schema` and the other `dox_validation` names come with `import 'package:dox_core/dox_core.dart'`.
A `schema.parse(...)` that fails inside a controller also answers `422`.

!!! warning "`Schema` from `dox_orm`"
    `dox_orm` also has a `Schema` class (the schema builder). In a file that imports both and uses `Schema`,
    add a prefix: `import 'package:dox_orm/dox_orm.dart' as orm;`.

## Custom rules

Add a rule name for rule strings:

```dart
class EvenRule extends Rule<Object?> {
    @override
    String get name => 'even';

    @override
    String get defaultMessage => 'The {field} must be even';

    @override
    bool check(Object? value, RuleContext context) {
        return int.tryParse('$value')?.isEven ?? false;
    }
}

v.registerRule('even', (RuleDefinition d) => EvenRule());
req.validate({'count': 'required|even'});
```

For a database check, extend `AsyncRule` and use `validateAsync`.
An unknown rule name throws an error when the rules are first used.

## Custom validation message

```dart
class BlogController {
    create(DoxRequest req) {
        req.validate({
                'title': 'required',
                'email': 'required|email',
            },
            messages: {
                'required' : 'the {field} is required',
                'email' : 'the {value} is not valid email',
            },
        );
    }
}
```

!!! info
    The validator will automatically substitute `{field}` and `{value}` with the corresponding request field and its value.

## Nested Validation

=== "Validation"

    ```dart
    class AddressController {
        create(DoxRequest req) {
            req.validate({
                'address.city': 'required',
                'address.post_code': 'required|numeric',
                'address.street.street_1': 'required',
                'address.street.street_2': 'required',
            });

            ....
        }
    }
    ```

=== "Request body"

    ```json
    {
        "address" : {
            "city" : "Bangkok",
            "post_code" : "10110",
            "street" : {
                "street_1" : "Chok Choi 4",
                "street_2" : "23/41 Main",
            }
        }
    }
    ```

## Nested with array

=== "Validation"

    ```dart
    class ProductController {
        create(DoxRequest req) {
            req.validate({
                'products.*.item': 'required',
                'products.*.base_price': 'required|double',
                'products.*.options.*.name': 'required',
                'products.*.options.*.price': 'required',
            });

            ....
        }
    }
    ```

=== "Request body"

    ```json
    {
        "products" : [
            {
                "item": "Shoes",
                "base_price": "20000",
                "options":  [
                    {"name" : "red", "price" : "21000"},
                    {"name" : "blue", "price" : "22000"},
                ]
            },
            {
                "item": "Nike",
                "base_price": "35000",
                "options":  [
                    {"name" : "green", "price" : "37000"},
                    {"name" : "purple", "price" : "38000"},
                ]
            }
        ]
    }
    ```

## Optional fields

!!! note "Changed in 3.x"
    Before 3.x, all rules ran on a missing field. So `'status': 'in:active,inactive'` failed when `status` was not sent.

A field that is missing, `null` or an empty string is optional.
Its other rules are skipped. Only `required`, `required_if` and `required_if_not` still run.

```dart
req.validate({
    'status': 'in:active,inactive', // passes when status is not sent
    'age': 'required|integer', // fails when age is not sent
});
```

## Rules

#### `nullable`

The field may be `null`. Other rules run only when it has a value.

```dart
req.validate({
    'age': 'nullable|integer',
});
```

#### `sometimes`

Validate the field only when it is sent. Use it with `required` to allow a missing field but reject an empty one.

```dart
req.validate({
    'name': 'sometimes|required',
});
```

#### `required`

```dart
req.validate({
    'name': 'required',
});
```

#### `required_if`

```dart
req.validate({
    'name': 'required_if:status,active',
    'status': 'in:active,inactive'
});
```

!!! info
    Name is required if status is active.

#### `required_if_not`

```dart
req.validate({
    'name': 'required_if_not:status,active',
    'status': 'in:active,inactive'
});
```

!!! info
    Name is required if status is inactive.

#### `unique`

The value must not be in the table yet. Async, use `validateAsync`.

```dart
await req.validateAsync({'email': 'required|email|unique:users,email'});
```

#### `exists`

The value must be in the table. Async, use `validateAsync`.

```dart
await req.validateAsync({'user_id': 'required|exists:users,id'});
```

#### `email`

```dart
req.validate({
    'user_email': 'email',
});
```

#### `string`

```dart
req.validate({
    'title': 'string',
});
```

#### `numeric`

```dart
req.validate({
    'price': 'numeric',
});
```

#### `boolean`

```dart
req.validate({
    'is_guest': 'boolean',
});
```

#### `integer`

```dart
req.validate({
    'price': 'integer',
});
```

#### `array`

```dart
req.validate({
    'product_ids': 'array',
});
```

#### `json`

```dart
req.validate({
    'product': 'json',
});
```

#### `ip`

```dart
req.validate({
    'user_ip_address': 'ip',
});
```

#### `alpha`

```dart
req.validate({
    'title': 'alpha',
});
```

#### `alpha_dash`

```dart
req.validate({
    'order_number': 'alpha_dash',
});
```

#### `alpha_numeric`

```dart
req.validate({
    'order_number': 'alpha_numeric',
});
```

#### `date`

```dart
req.validate({
    'dob': 'date',
});
```

#### `url`

```dart
req.validate({
    'return_url': 'url',
});
```

#### `uuid`

```dart
req.validate({
    'user_id': 'uuid',
});
```

#### `in`

```dart
req.validate({
    'status': 'in:active,inactive',
});
```

!!! info
    Status field must be one of active or inactive status.

#### `not_in`

```dart
req.validate({
    'status': 'not_in:active,inactive',
});
```

#### `start_with`

```dart
req.validate({
    'title': 'start_with:dox',
});
```

!!! info
    Title string must start with text `dox`.

#### `end_with`

```dart
req.validate({
    'title': 'end_with:framework',
});
```

!!! info
    Title string must end with text `framework`.

#### `confirmed`

Confirm can be used to verify password.

=== "Validation"

    ```dart
    req.validate({
        'password': 'confirmed',
    });
    ```

=== "Request body"

    ```dart
    {
        "password" => "12345678"
        "password_confirmation" => "12345678"
    }
    ```

!!! info
    By default, it will verify against the `password_confirmation` field. However, you can also employ a custom name to confirm the password.

    ```dart
    req.validate({
        'password': 'confirmed:confirm_password'
    });
    ```

=== "Request body"

    ```dart
    {
        "password" => "12345678"
        "confirm_password" => "12345678"
    }
    ```

#### `image`

=== "All image extensions"

    ```dart
    request.validate({
        'profile_pic': 'image',
    });
    ```

=== "Only specific image extensions"

    ```dart
    request.validate({
        'profile_pic': 'image:png,jpeg,gif,jpg',
    });
    ```

#### `file`

=== "All file extensions"

    ```dart
    request.validate({
        'attachment': 'file',
    });
    ```

=== "Only specific file extensions"

    ```dart
    request.validate({
        'attachment': 'file:png,pdf,docx',
    });
    ```

### character

#### `min_length`

```dart
req.validate({
    'title': 'min_length:20',
});
```

!!! info
    `min_length` and `max_length` include the limit. `min_length:20` accepts 20 characters.

#### `max_length`

```dart
req.validate({
    'title': 'max_length:100',
});
```

#### `length_between`

```dart
req.validate({
    'title': 'length_between:20,100',
});
```

### number

#### `min`

```dart
req.validate({
    'price': 'min:20',
});
```

#### `max`

```dart
req.validate({
    'price': 'max:100',
});
```

#### `between`

```dart
req.validate({
    'price': 'between:20,100',
});
```

#### `greater_than`

```dart
req.validate({
    'price': 'greater_than:20',
});
```

#### `less_than`

```dart
req.validate({
    'price': 'less_than:100',
});
```
