class IocContainer {
  Map<Type, dynamic> dependencies = {};
  Map<Type, dynamic> singletonDependencies = {};

  register<T>(Function(IocContainer) callback) {
    dependencies[T] = () => callback(this);
  }

  registerSingleton<T>(Function(IocContainer) callback) {
    singletonDependencies[T] = callback(this);
  }

  _haveInSingleton<T>() {
    return singletonDependencies[T] != null;
  }

  T get<T>() {
    if (_haveInSingleton<T>()) {
      return singletonDependencies[T];
    }
    return dependencies[T]();
  }
}
