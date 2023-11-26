class IocContainer {
  final Map<String, dynamic> _dependencies = <String, dynamic>{};
  final Map<String, dynamic> _singletonDependencies = <String, dynamic>{};

  /// register a request class in ioc container
  /// ```
  /// ioc.registerRequest('BlogRequest', () => BlogRequest());
  /// ```
  void registerRequest(String name, Function callback) {
    if (name != 'dynamic') {
      _dependencies[name] = () => callback();
    }
  }

  /// register a class in ioc container
  /// ```
  /// ioc.registerByName('name', (i) => Bar());
  /// ioc.registerByName('name', (i) => Foo(i.get<Bar>()));
  /// ```
  void registerByName(String name, Function(IocContainer) callback) {
    if (name != 'dynamic') {
      _dependencies[name] = () => callback(this);
    }
  }

  /// register a class in ioc container
  /// ```
  /// ioc.register<Bar>((i) => Bar());
  ///
  /// ioc.register<Foo>((i) => Foo(i.get<Bar>()));
  /// ```
  void register<T>(Function(IocContainer) callback) {
    if (T.toString() != 'dynamic') {
      _dependencies[T.toString()] = () => callback(this);
    }
  }

  /// register as singleton in ioc container
  /// ```
  /// ioc.registerSingleton<Bar>((i) => Bar());
  /// ```
  /// bar will create only once instance
  void registerSingleton<T>(Function(IocContainer) callback) {
    if (T.toString() != 'dynamic') {
      _singletonDependencies[T.toString()] = callback(this);
    }
  }

  /// get class
  /// ```
  /// Foo foo = ioc.get<Foo>();
  /// ```
  T get<T>() {
    if (_haveInSingleton(T.toString())) {
      return _singletonDependencies[T.toString()];
    }
    return _dependencies[T.toString()]();
  }

  /// get class
  /// ```
  /// Foo foo = ioc.get<Foo>();
  /// ```
  dynamic getByName(String name) {
    if (_haveInSingleton(name)) {
      return _singletonDependencies[name];
    }
    return _dependencies[name] != null ? _dependencies[name]() : null;
  }

  bool _haveInSingleton(String name) {
    return _singletonDependencies[name] != null;
  }
}
