# Isolate

Dox support multi-threaded HTTP server using isolates that can handle 10x concurrency requests with high speed.

```dart
class Config extends AppConfig {
    @override
    int get totalIsolate => 3;

    ...
}
```

By default, Dox runs on three isolates. You can configure this setting in the `lib/config/app.dart` file.