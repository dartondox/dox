import 'model.dart';

/// makes models with test or seed data.
///
/// ```
/// class UserFactory extends Factory<User> {
///   @override
///   User definition() => User()
///     ..name = 'User'
///     ..email = 'user@example.com';
/// }
///
/// List<User> users = await UserFactory().count(10).create();
/// User admin = await UserFactory()
///     .state((User u) => u..isAdmin = true)
///     .createOne();
/// ```
///
/// the methods change this factory and return it, so you can chain them.
/// make a new factory for each set of models.
abstract class Factory<T extends Model<T>> {
  int _count = 1;

  /// states and sequences, in the order they were added
  final List<T Function(T model, int index)> _states =
      <T Function(T model, int index)>[];

  /// runs after each model of [create] is saved, see [has]
  final List<Future<void> Function(T parent)> _afterCreate =
      <Future<void> Function(T parent)>[];

  /// a new model with the default values. it runs once per model, so
  /// random values are new each time.
  T definition();

  /// how many models [make] and [create] give. default 1.
  Factory<T> count(int count) {
    if (count < 0) throw ArgumentError.value(count, 'count', 'is negative');
    _count = count;
    return this;
  }

  /// change each model after [definition], eg.
  /// `state((User u) => u..isAdmin = true)`.
  /// it also sets a parent, eg. `state((Post p) => p..userId = user.id)`.
  Factory<T> state(T Function(T model) state) {
    _states.add((T model, int index) => state(model));
    return this;
  }

  /// like [state], with the index of the model (0, 1, 2, ...), eg.
  /// `sequence((User u, int i) => u..email = 'user$i@example.com')`.
  Factory<T> sequence(T Function(T model, int index) state) {
    _states.add(state);
    return this;
  }

  /// after [create] saves each model, also create the models of
  /// [children]. [link] sets the parent on each child, eg.
  ///
  /// ```
  /// await UserFactory()
  ///     .has(PostFactory().count(3), (Post p, User u) => p..userId = u.id)
  ///     .create();
  /// ```
  Factory<T> has<C extends Model<C>>(
    Factory<C> children,
    C Function(C child, T parent) link,
  ) {
    _afterCreate.add(
      (T parent) => children._create((C child) => link(child, parent)),
    );
    return this;
  }

  /// [count] models, not saved
  List<T> make() => _make(null);

  /// one model, not saved. [count] is not used.
  T makeOne() => _makeAt(0, null);

  /// [count] models, saved one by one with `save()`, so model events run
  Future<List<T>> create() => _create(null);

  /// one model, saved. [count] is not used.
  Future<T> createOne() async {
    T model = _makeAt(0, null);
    await _save(model);
    return model;
  }

  List<T> _make(T Function(T model)? extra) {
    return <T>[for (int i = 0; i < _count; i++) _makeAt(i, extra)];
  }

  T _makeAt(int index, T Function(T model)? extra) {
    T model = definition();
    for (T Function(T model, int index) state in _states) {
      model = state(model, index);
    }
    return extra == null ? model : extra(model);
  }

  Future<List<T>> _create(T Function(T model)? extra) async {
    List<T> models = _make(extra);
    for (T model in models) {
      await _save(model);
    }
    return models;
  }

  Future<void> _save(T model) async {
    await model.save();
    for (Future<void> Function(T parent) after in _afterCreate) {
      await after(model);
    }
  }
}
