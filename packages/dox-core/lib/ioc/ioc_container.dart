import 'package:dox_core/dox_core.dart';

/// Makes one object for the container. It gets the container, so it can
/// ask for the objects it needs.
typedef IocFactory<T> = T Function(IocContainer c);

/// One registration: how to make the object, and the object once made.
class _Binding {
  _Binding(this.make, {required this.shared, this.value});

  final Object Function(IocContainer c) make;

  /// true: one instance, kept in [value]. false: a new one each time.
  final bool shared;
  Object? value;
}

/// The Dox container. It makes your classes and gives their
/// constructors what they need.
///
/// You do not fill it by hand. Put `@Inject()` above a class, run
/// `dart run build_runner build`, and set
/// `AppConfig(container: registerContainer)` from `lib/container.g.dart`.
///
/// Each isolate has its own container (`Dox().ioc`), so a singleton is
/// one instance per isolate. It is made on first use.
/// ```
/// UserService users = Dox().ioc.get<UserService>();
/// ```
class IocContainer {
  final Map<Type, _Binding> _bindings = <Type, _Binding>{};

  /// types set with [override]. A normal registration does not
  /// replace them.
  final Set<Type> _overrides = <Type>{};

  /// the types being made now, to find a cycle
  final List<Type> _making = <Type>[];

  final List<Type> _routers = <Type>[];
  final List<Type> _services = <Type>[];
  final Map<Type, RouteBinder<Object>> _modelBinders =
      <Type, RouteBinder<Object>>{};

  /// One instance of [T] per container (per isolate), made on first use.
  /// ```
  /// c.singleton<UserService>((IocContainer c) {
  ///   return UserService(c.get<UserRepository>());
  /// });
  /// ```
  void singleton<T extends Object>(IocFactory<T> make) {
    _bind(T, _Binding(make, shared: true));
  }

  /// A new instance of [T] on every [get].
  void factory<T extends Object>(IocFactory<T> make) {
    _bind(T, _Binding(make, shared: false));
  }

  /// [value] is the instance of [T]. Use it for config values.
  /// ```
  /// c.instance<MailConfig>(MailConfig(host: 'smtp.example.com'));
  /// ```
  void instance<T extends Object>(T value) {
    _bind(T, _Binding(_made, shared: true, value: value));
  }

  /// Replace [T] with [value], eg. a fake in a test. It stays when the
  /// app registers its classes again (`Dox().initialize()`), until
  /// [clearOverrides]. Call it before the server starts: a controller
  /// gets its objects once, at start.
  /// ```
  /// Dox().ioc.override<UserRepository>(FakeUserRepository());
  /// client = await DoxTestClient.start(appConfig);
  /// ```
  void override<T extends Object>(T value) {
    _overrides.add(T);
    _bindings[T] = _Binding(_made, shared: true, value: value);
    _forgetInstances();
  }

  /// Remove every [override]. The next `Dox().initialize()` registers
  /// the real classes again.
  void clearOverrides() {
    for (Type type in _overrides) {
      _bindings.remove(type);
    }
    _overrides.clear();
    _forgetInstances();
  }

  /// The instance of [T]. Throws a [StateError] when [T] is not
  /// registered.
  T get<T extends Object>() {
    return getByType(T) as T;
  }

  /// True when [T] is registered.
  bool has<T extends Object>() {
    return _bindings.containsKey(T);
  }

  /// [T] is a router. Dox registers its routes at start.
  /// `lib/container.g.dart` calls this for every class that extends
  /// `Router`.
  void router<T extends Router>(IocFactory<T> make) {
    singleton<T>(make);
    if (!_routers.contains(T)) _routers.add(T);
  }

  /// [T] is a service. Dox runs its `setup()` at start, in every
  /// isolate. `lib/container.g.dart` calls this for every class that
  /// implements `DoxService`.
  void service<T extends DoxService>(IocFactory<T> make) {
    singleton<T>(make);
    if (!_services.contains(T)) _services.add(T);
  }

  /// A route param for a controller parameter of type [T] is turned into
  /// a [T] with [find]. `lib/container.g.dart` calls this for every
  /// `@DoxModel`. `Route.bind` wins over it.
  void bindModel<T extends Object>(RouteBinder<T> find) {
    _modelBinders[T] = find;
  }

  /// The routers, made from the container, in the order they were added.
  List<Router> get routers {
    return <Router>[for (Type type in _routers) getByType(type) as Router];
  }

  /// The services, made from the container, in the order they were added.
  List<DoxService> get services {
    return <DoxService>[
      for (Type type in _services) getByType(type) as DoxService,
    ];
  }

  /// Remove every registration, but not the [override]s.
  /// `Dox().initialize()` calls it before it registers the app classes.
  void clear() {
    _bindings.removeWhere(_notOverridden);
    _routers.clear();
    _services.clear();
    _modelBinders.clear();
  }

  /// The instance of [type]. Same as [get], for a [Type] value.
  Object getByType(Type type) {
    _Binding? binding = _bindings[type];
    if (binding == null) {
      throw StateError(
        '$type is not in the container. Add @Inject() above the class and '
        'run `dart run build_runner build`. Then set '
        '`AppConfig(container: registerContainer)`.',
      );
    }
    Object? value = binding.value;
    if (value != null) return value;
    if (_making.contains(type)) {
      String chain = <Type>[..._making, type].join(' -> ');
      throw StateError('Dependency cycle in the container: $chain');
    }
    _making.add(type);
    try {
      Object made = binding.make(this);
      if (binding.shared) binding.value = made;
      return made;
    } finally {
      _making.removeLast();
    }
  }

  /// True when [type] gives the same instance every time.
  bool isShared(Type type) {
    return _bindings[type]?.shared ?? false;
  }

  /// The registered type with the name [name] (like `UserService`), or
  /// null. Throws a [StateError] when two types have this name.
  /// Dox uses it at start to read controller parameters. Not for the
  /// request path: it is slow.
  Type? typeNamed(String name) {
    return _named(_bindings.keys, name);
  }

  /// The [bindModel] binder for the type named [name], or null.
  RouteBinder<Object>? modelBinderNamed(String name) {
    Type? type = _named(_modelBinders.keys, name);
    return type == null ? null : _modelBinders[type];
  }

  /// Put [value] in the place of its type, when that type is
  /// registered and not overridden. Dox calls it for the services of
  /// `AppConfig.services`, so the container gives the same instance.
  void adopt(Object value) {
    Type type = value.runtimeType;
    _Binding? binding = _bindings[type];
    if (binding == null || _overrides.contains(type)) return;
    _bindings[type] = _Binding(_made, shared: true, value: value);
  }

  void _bind(Type type, _Binding binding) {
    if (_overrides.contains(type)) return;
    _bindings[type] = binding;
  }

  /// after an override, made singletons may hold the old object
  void _forgetInstances() {
    for (MapEntry<Type, _Binding> entry in _bindings.entries) {
      _Binding binding = entry.value;
      if (binding.shared && !identical(binding.make, _made)) {
        binding.value = null;
      }
    }
  }

  bool _notOverridden(Type type, _Binding binding) {
    return !_overrides.contains(type);
  }

  static Type? _named(Iterable<Type> types, String name) {
    Type? found;
    for (Type type in types) {
      if (type.toString() != name) continue;
      if (found != null) {
        throw StateError(
          'Two classes in the container are named $name. Dox can not tell '
          'them apart from a parameter type. Use the typed route style: '
          'Route.get<$name>(path, ($name c) => c.method).',
        );
      }
      found = type;
    }
    return found;
  }

  /// the factory of an [instance]: never called, the value is set
  static Object _made(IocContainer c) {
    throw StateError('unreachable');
  }
}
