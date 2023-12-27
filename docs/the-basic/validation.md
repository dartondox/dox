# Validation

Dox offers multiple approaches for validating the request data in your application.

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

## Rules

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
