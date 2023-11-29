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

## Custom Drivers

To create a custom driver, you have the option to implement the `CacheDriverInterface`. See sample below for redis driver.

### Redis Driver

=== "1. Crete redis service"

    ```dart
    import 'package:dox_core/dox_core.dart';
    import 'package:redis/redis.dart';

    class Redis implements DoxService {
        /// Declare as Singleton to reuse connection
        static final Redis _i = Redis._internal();
        factory Redis() => _i;
        Redis._internal();

        late Command command;

        @override
        Future<void> setup() async {
            RedisConnection conn = RedisConnection();
            String tls = Env.get('REDIS_TLS', 'false');
            String host = Env.get('REDIS_HOST', 'localhost');
            int port = int.parse(Env.get('REDIS_PORT', '6379'));

            if (tls == 'true') {
                Redis().command = await conn.connectSecure(host, port);
            } else {
                Redis().command = await conn.connect(host, port);
            }

            String username = Env.get('REDIS_USERNAME', '');
            String password = Env.get('REDIS_PASSWORD', '');

            if (username.isNotEmpty && password.isNotEmpty) {
                await Redis().command.send_object(
                    <dynamic>['AUTH', username, password],
                );
            }
        }
    }
    ```


=== "2. Register in dox"

    ```dart
    void main() async {
        /// Initialize Dox
        Dox().initialize(Config());
        ...

        /// register redis connection
        Dox().addService(Redis());

        ...
        /// start dox http server
        await Dox().startServer();
    }

    ```

=== "3. Create redis driver"

    ```dart
    import 'package:dox_core/cache/cache_driver_interface.dart';
    import 'package:redis/redis.dart';

    import '../config/redis.dart';

    class RedisCacheDriver implements CacheDriverInterface {
        @override
        String tag = '';

        @override
        String get prefix => 'dox-framework-cache-$tag:';

        RedisCacheDriver();

        @override
        void setTag(String tagName) {
            tag = tagName;
        }

        @override
        Future<void> flush() async {
            Command cmd = Redis().command;
            List<dynamic> res = await cmd.send_object(<dynamic>['KEYS', '$prefix*']);
            if (res.isNotEmpty) {
                await cmd.send_object(<dynamic>['DEL', ...res]);
            }
        }

        @override
        Future<void> forever(String key, String value) async {
            await put(key, value, duration: Duration(days: 365 * 1000));
        }

        @override
        Future<void> forget(String key) async {
            Command cmd = Redis().command;
            return await cmd.send_object(<dynamic>['DEL', prefix + key]);
        }

        @override
        Future<dynamic> get(String key) async {
            Command cmd = Redis().command;
            return await cmd.send_object(<dynamic>['GET', prefix + key]);
        }

        @override
        Future<bool> has(String key) async {
            dynamic val = await get(key);
            return val != null ? true : false;
        }

        @override
        Future<void> put(String key, String value, {Duration? duration}) async {
            duration = duration ?? Duration(hours: 1);
            DateTime time = DateTime.now().add(duration);

            Command cmd = Redis().command;

            await cmd.send_object(<dynamic>[
                'SET',
                prefix + key,
                value,
                'PXAT',
                time.millisecondsSinceEpoch,
            ]);
        }
    }
    ```

=== "4. Register redis driver"

    ```dart

    /// register redis cache driver in `lib/config/app.dart`
    @override
    CacheConfig get cacheConfig => CacheConfig(
        defaultDriver: 'redis',
        drivers: <String, CacheDriverInterface>{
          'file': FileCacheDriver(),
          'redis': RedisCacheDriver(),
        },
    );
    ```

!!! info
    See more detail about Dox services [here](services.md).