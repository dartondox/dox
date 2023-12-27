# Isolate

Dox support multi-threaded HTTP server using isolates that can handle 10x concurrency requests with high speed.

By default, Dox runs on three isolates. You can configure this setting in the `lib/config/app.dart` file. Or simply add like `APP_TOTAL_ISOLATE=6` in environment variable.


```dart
totalIsolate: Env.get<int>('APP_TOTAL_ISOLATE', 6),
```