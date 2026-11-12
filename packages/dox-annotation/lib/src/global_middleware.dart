/// Middleware that packages add at startup. dox_core puts them in
/// front of the app's own globalMiddleware.
class GlobalMiddleware {
  static final List<Object> _items = <Object>[];

  /// add [middleware] once (a second add of the same one is skipped)
  static void add(Object middleware) {
    if (!_items.contains(middleware)) _items.add(middleware);
  }

  /// the added middleware, in order
  static List<Object> get items => List<Object>.unmodifiable(_items);

  /// remove all. For tests only.
  static void clear() => _items.clear();
}
