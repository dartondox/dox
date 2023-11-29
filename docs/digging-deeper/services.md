# Services

If your application requires additional services like a database or Redis, you'll need to create a class that implements the `DoxService` interface and then register it with Dox. Since Dox operates with isolates (multi-threading), these extra services must be passed to each isolate to ensure their availability on all isolates.

### Example with redis

=== "Redis service"

    ```dart
    class Redis implements DoxService {
        /// Declare as Singleton reuse connection
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

#####
=== "Register into dox `bin/server.dart`"

    ```dart
    void main() async {
        /// Initialize Dox
        Dox().initialize(Config());

        /// register redis service
        Dox().addService(Redis());

        /// start dox http server
        await Dox().startServer();
    }
    ```