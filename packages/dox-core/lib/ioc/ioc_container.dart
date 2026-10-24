class IocContainer {
  final Map<String, dynamic> _dependencies = <String, dynamic>{};
  final Map<String, dynamic> _singletonDependencies = <String, dynamic>{};

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
    String name = T.toString();
    if (name != 'dynamic') {
      _dependencies[name] = () => callback(this);
    }
  }

  /// register as singleton in ioc container
  /// ```
  /// ioc.registerSingleton<Bar>((i) => Bar());
  /// ```
  /// bar will create only once instance
  void registerSingleton<T>(Function(IocContainer) callback) {
    String name = T.toString();
    if (name != 'dynamic') {
      _singletonDependencies[name] = callback(this);
    }
  }

  /// get class
  /// ```
  /// Foo foo = ioc.get<Foo>();
  /// ```
  T get<T>() {
    /// `T.toString()` makes a new string, so call it once
    String name = T.toString();
    if (_haveInSingleton(name)) {
      return _singletonDependencies[name];
    }
    return _dependencies[name]();
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
