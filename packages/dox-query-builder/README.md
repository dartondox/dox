# dox_query_builder

This package is replaced by [dox_orm](https://pub.dev/packages/dox_orm).

It only re-exports `dox_orm`, so old code keeps working. Please move to `dox_orm`:

1. In `pubspec.yaml`, change `dox_query_builder` to `dox_orm`.
2. Change imports:

```dart
// old
import 'package:dox_query_builder/dox_query_builder.dart';
// new
import 'package:dox_orm/dox_orm.dart';
```

New features and fixes go to `dox_orm` only.
