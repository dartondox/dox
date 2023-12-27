# Services

If your application requires additional services like a database, auth etc.., you'll need to create a class that implements the `DoxService` interface and then register it with Dox. Since Dox operates with isolates (multi-threading), these extra services must be passed to each isolate to ensure their availability on all isolates.

### Example with auth

=== "AuthService"

    ```dart
    class AuthService implements DoxService {
        @override
        void setup() {
            Auth.initialize(AuthConfig(
            /// default auth guard
            defaultGuard: 'web',

            /// list of auth guards
            guards: <String, AuthGuard>{
                'web': AuthGuard(
                driver: JwtAuthDriver(secret: SecretKey(Env.get('APP_KEY'))),
                provider: AuthProvider(
                    model: () => User(),
                ),
                ),
            },
            ));
        }
    }
    ```

#####
=== "Register into dox `app/config/services.dart`"

```dart
List<DoxService> services = <DoxService>[
  ... /// other services
  AuthService,
];
```

 