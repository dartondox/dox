# Request input (raw values)

These values are not checked. Use a DTO to check input. Ask for `DoxRequest` in the controller:

```dart
String? name = req.input('name');          // query or body. The body wins.
String city = req.input('user.city', 'x');  // dot key, with a default
Map<String, dynamic> all = req.all();
Map<String, dynamic> some = req.only(<String>['name', 'email']);
bool remember = req.boolean('remember');
int page = req.integer('page', 1);
String? token = req.header('X-Token');
String? bearer = req.bearerToken();
String? theme = req.cookie('theme');
RequestFile? file = req.file('image');
String ip = req.ip();
```

More request helpers:

```dart
req.path();                   // '/admin/users/5'
req.fullUrl();                // 'https://example.com/admin/users/5?tab=info'
req.routeIs('admin.users.*'); // true when the route name matches
req.isJson();                 // true for a JSON body
req.hasFile('image');         // true when the field holds a file
```

Upload a file with a DTO, so Dox checks its type and size:

```dart
@Dto()
class UploadImage {
  @Image()
  @MaxSize('5MB')
  final RequestFile image;

  const UploadImage({required this.image});

  static const DtoSchema<UploadImage> schema = $UploadImageDto;
}
```

A temp upload file is deleted when the response is sent. Save it (`store`, `moveTo`) before you return.
`input.image.store('images')` needs the `dox_storage` package.

Docs: https://dartondox.dev/latest/the-basic/request/
