/// Puts a class in the Dox container. `dox_builder` finds it and writes
/// `lib/container.g.dart`, so you never register it by hand.
///
/// The constructor parameters come from the container, by type.
/// Each isolate makes one instance, on first use. With
/// `@Inject(singleton: false)` every `get` makes a new one.
/// ```
/// @Inject()
/// class UserService {
///   UserService(this.users);
///
///   final UserRepository users;
/// }
/// ```
class Inject {
  const Inject({this.singleton = true});

  /// true (the default): one instance per isolate.
  /// false: a new instance each time.
  final bool singleton;
}
