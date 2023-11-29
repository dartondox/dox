# Request

## Request body

You can use the map function to retrieve body data using `req.body['keyword']`. You can use the `req.body` to retrieve data from both JSON body and request parameters, like `?foo=bar`, by utilizing the map function.

```dart
class ApiController {
    sayHello(DoxRequest req) {
        String name = req.body['name']
        return 'Hello $name';
    }
}
```

## Route Param

Route parameters can be optional and can also be obtained from `req.param`.

```dart
Route.get('/hello/{name}');

class ApiController {
    sayHello(DoxRequest req, String name) {
        return 'Hello $name';
    }
}
```

## Form data (File)

To access the uploaded image file from the request, the code utilizes the `req.input('image')` method. This assumes that the incoming request is structured as a 'multipart/form-data' form with a file input field named `image`.

```dart
class ApiController {
    uploadImage(DoxRequest req, String name) {
        req.validate({
            'image': 'required|image:png,jpg',
        });
        
        RequestFile image = req.input('image');
        String uploadedPath = await image.store();
        
        return {"filename" : uploadedPath};
    }
}
```

## Custom Form Request

#### Step 1. Create a request

```bash
dox create:request Blog
```

#### Step 2. Register in app

Register a request in `lib/config/app.dart`

```dart
@override
Map<Type, Function()> get formRequests => {
    BlogRequest:() => BlogRequest(),
};
```

!!! info "Why?"
    If we don't utilize `dart:mirrors`, there isn't a straightforward method to instantiate a class from a string in Dart. Instead, we must register your request class in the `app.dart` file. As a result, Dox will seamlessly route the request to the corresponding controller.

#### Step 3. Usage

=== "blog.request.dart"

    ```dart
    import 'package:dox_core/dox_core.dart';

    class BlogRequest extends FormRequest {
        String? title;
        String? description;

        @override
        void setUp() {
            title = input('title');
            description = input('desc');
        }

        @override
        Map<String, String> rules() {
            return {
                'title': 'required',
            };
        }

        @override
        Map<String, String> messages() {
            return {
                'required': "The {attribute} is required"
            };
        }
    }
    ```

=== "blog.controller.dart"

    ```dart
    class BlogController {
        store(BlogRequest req) async {
            Blog blog = Blog();
            
            blog.title = req.title;
            blog.description = req.description;
            
            await blog.save();
            return blog;
        }
    }
    ```

#### `setUp`

Within this function, you have the opportunity to assign values to variables based on the incoming request, which can then be reused within the controller.

#### `rules`

This function serves as the location for defining validation rules for input requests.

#### `messages`

In this function, you have the ability to configure custom validation messages for input form request validation. Check [here](validation.md#custom-validation-message) for more about validation.