# Cache

Your application may involve data retrieval or processing tasks that are computationally intensive or time-consuming, potentially taking several seconds to finish. In such situations, it's a common practice to temporarily store the obtained data in a cache, enabling swift retrieval for subsequent requests requiring the same information. Typically, this cached data is stored in high-speed data stores like Memcached or Redis.

Thankfully, Dox offers a versatile and consistent API for various cache backends, empowering you to harness their rapid data retrieval capabilities and enhance the performance of your web application.

## Usage

### `put`

```dart
// Default duration is 1 hour

await Cache().put('foo', 'bar');
```

```dart
// With custom duration

await Cache().put('delay', 'Dox', duration: Duration(microseconds: 1));
```

### `forever`

```dart
// Store data in cache forever.

await Cache().forever('foo', 'bar');
```

### `get`

```dart
// Get stored cache with cache key.

await Cache().get('foo');
```

### `has`

```dart
// Check key exist in cache

await Cache().has('foo'); // this will return boolean
```

### `forget`

```dart
// Delete a cache with cache key

await Cache().forget('foo');
```

### `tag`

```dart
// Set a tag to store cache

await Cache().tag('folder').put('foo', 'bar');
await Cache().tag('folder').get('foo');
await Cache().tag('folder').flush();
```

!!! info
    tag is like a folder name to store cache.

### `flush`

```dart
// Delete all the cache keys

await Cache().flush();
```

### `store`

```dart
// Set driver name

await Cache().store('redis').put('foo', 'bar');
await Cache().store('file').put('foo', 'bar');
```

!!! info
    If you have multiple drivers, you can use `store()` method to set the driver name. By default it will be `file` driver.
