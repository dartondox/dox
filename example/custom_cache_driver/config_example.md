```dart
class Config extends AppConfig {
    ...

    @override
    CacheDriverInterface? get customCacheDriver => RedisCacheDriver();
}
```
