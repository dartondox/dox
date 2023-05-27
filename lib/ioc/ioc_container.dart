class IocContainer {
  final Map<Type, dynamic> _dependencies = {};
  final Map<Type, dynamic> _singletonDependencies = {};

  /// register a class in ioc container
  /// ```
  /// ioc.register<Bar>((i) => Bar());
  ///
  /// ioc.register<Foo>((i) => Foo(i.get<Bar>()));
  /// ```
  register<T>(Function(IocContainer) callback) {
    _dependencies[T] = () => callback(this);
  }

  /// register as singleton in ioc container
  /// ```
  /// ioc.registerSingleton<Bar>((i) => Bar());
  /// ```
  /// bar will create only once instance
  registerSingleton<T>(Function(IocContainer) callback) {
    _singletonDependencies[T] = callback(this);
  }

  /// get class
  /// ```
  /// Foo foo = ioc.get<Foo>();
  /// ```
  T get<T>() {
    if (_haveInSingleton<T>()) {
      return _singletonDependencies[T];
    }
    return _dependencies[T]();
  }

  _haveInSingleton<T>() {
    return _singletonDependencies[T] != null;
  }
}
