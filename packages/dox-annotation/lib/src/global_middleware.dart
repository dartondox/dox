import 'dart:collection';

/// Middleware that packages add at startup. dox_core puts them in
/// front of the app's own globalMiddleware.
///
/// dox_core clears the list each time the app starts, before the
/// providers run `setup()`. So add from `setup()`.
class GlobalMiddleware {
  static final List<Object> _items = <Object>[];
  static List<Object> _view = UnmodifiableListView<Object>(_items);

  /// goes up on every change
  static int version = 0;

  /// add [middleware] once (a second add of the same one is skipped).
  /// The check uses `==`. Use a top-level function or a const instance.
  static void add(Object middleware) {
    if (_items.contains(middleware)) return;
    _items.add(middleware);
    _changed();
  }

  /// the added middleware, in order
  static List<Object> get items => _view;

  /// remove all. dox_core calls it at each start. Also for tests.
  static void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    _changed();
  }

  static void _changed() {
    version++;
    _view = UnmodifiableListView<Object>(List<Object>.of(_items));
  }
}
