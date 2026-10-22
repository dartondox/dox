import 'dart:async';

import '../dox_orm.dart';

class Model<T> extends QueryBuilder<T> {
  /// primary key value, it can be any type (int, uuid string...)
  dynamic tempIdValue;
  DateTime? createdAt;
  DateTime? updatedAt;

  /// fields left out of toJson()
  List<String> get hidden => _hidden ??= <String>[];
  set hidden(List<String> value) => _hidden = value;
  List<String>? _hidden;

  /// the generator overrides it with the model columns
  List<String> get tableColumns => _tableColumns ??= <String>[];
  set tableColumns(List<String> value) => _tableColumns = value;
  List<String>? _tableColumns;

  bool _debug = SqlQueryBuilder().debug;

  /// values we last saved, so save() can tell when a field was set to null
  Map<String, dynamic>? _savedValues;

  @override
  String get tableName => helper.tableNameOf(runtimeType);

  @override
  dynamic get self => this;

  // coverage:ignore-start
  Map<String, dynamic> get timestampsColumn => <String, dynamic>{
    'created_at': 'created_at',
    'updated_at': 'updated_at',
  };
  // coverage:ignore-end

  @override
  Model<T> debug([bool? debug]) {
    _debug = debug ?? true;
    super.debug(debug);
    return this;
  }

  /// create new record in table
  ///
  /// ```
  /// Blog blog = new Blog();
  /// blog.title = 'blog title';
  /// await blog.save()
  /// ```
  ///
  /// It fires the model events (saving, creating or updating, then
  /// created or updated, then saved). It returns false when a hook
  /// throws [CancelModelEvent].
  Future<bool> save() async {
    if (!_eventsOn) {
      await _save();
      return true;
    }
    bool isNew = tempIdValue == null;
    try {
      await _fire(ModelEvent.saving);
      await _fire(isNew ? ModelEvent.creating : ModelEvent.updating);
    } on CancelModelEvent {
      return false;
    }
    await _save();
    await _fire(isNew ? ModelEvent.created : ModelEvent.updated);
    await _fire(ModelEvent.saved);
    return true;
  }

  /// save without firing model events
  Future<void> saveQuietly() => _save();

  Future<void> _save() async {
    String? createdAtColumn = timestampsColumn['created_at'];
    String? updatedAtColumn = timestampsColumn['updated_at'];

    Map<String, dynamic> values = toMap(removeRelations: true);
    DateTime currentTime = now();
    if (values[primaryKey] == null) {
      values.removeWhere((String key, dynamic value) => value == null);

      if (createdAtColumn != null) {
        values[createdAtColumn] = currentTime;
        createdAt = values[createdAtColumn];
      }

      if (updatedAtColumn != null) {
        values[updatedAtColumn] = currentTime;
        updatedAt = values[updatedAtColumn];
      }

      Map<String, dynamic> res = await QueryBuilder.table(tableName)
          .setPrimaryKey(primaryKey)
          .debug(_debug)
          .insert(values);

      tempIdValue = res[primaryKey];
      _savedValues = <String, dynamic>{...values, primaryKey: tempIdValue};
    } else {
      dynamic id = values[primaryKey];
      values.remove(primaryKey);
      values.remove(createdAtColumn);

      /// only send null when the field had a value before (set to null).
      /// a field we never loaded or saved is skipped, so a model loaded
      /// with select() does not clear the other columns.
      Map<String, dynamic> saved = _savedValues ?? originalMap;
      values.removeWhere(
        (String key, dynamic value) => value == null && saved[key] == null,
      );
      _savedValues = <String, dynamic>{...saved, ...values};
      if (updatedAtColumn != null) {
        values[updatedAtColumn] = currentTime;
        updatedAt = values[updatedAtColumn];
      }

      await QueryBuilder.table(tableName, this)
          .setPrimaryKey(primaryKey)
          .debug(_debug)
          .where(primaryKey, id)
          .update(values);
    }
  }

  /// delete this record (soft delete when the model use SoftDeletes)
  ///
  /// ```
  /// Blog? blog = await Blog().find(1);
  /// await blog?.delete();
  /// ```
  ///
  /// It fires deleting and deleted. A query delete like
  /// `Blog().where('id', 1).delete()` fires no events.
  @override
  Future<bool> delete() async {
    /// a query delete: Blog().where('id', 1).delete()
    if (tempIdValue == null) {
      await super.delete();
      return true;
    }
    bool events = _eventsOn;
    if (events) {
      try {
        await _fire(ModelEvent.deleting);
      } on CancelModelEvent {
        return false;
      }
    }
    if (isSoftDeletes) {
      await _thisRecord().update(<String, dynamic>{'deleted_at': now()});
    } else {
      await _thisRecord().forceDelete();
    }
    if (events) await _fire(ModelEvent.deleted);
    return true;
  }

  /// delete this record from the table, also when soft deleted.
  /// It fires forceDeleting, deleting, deleted, then forceDeleted.
  @override
  Future<bool> forceDelete() async {
    if (tempIdValue == null) {
      await super.forceDelete();
      return true;
    }
    bool events = _eventsOn;
    if (events) {
      try {
        await _fire(ModelEvent.forceDeleting);
        await _fire(ModelEvent.deleting);
      } on CancelModelEvent {
        return false;
      }
    }
    await _thisRecord().forceDelete();
    if (events) {
      await _fire(ModelEvent.deleted);
      await _fire(ModelEvent.forceDeleted);
    }
    return true;
  }

  /// a new query on this row only, so the query state of this model
  /// (where, values of an old query) is not used again
  QueryBuilder<T> _thisRecord() {
    return QueryBuilder.table<T>(
      tableName,
      this,
    ).setPrimaryKey(primaryKey).debug(_debug).where(primaryKey, tempIdValue);
  }

  /// restore this soft deleted record. It fires restoring and restored.
  ///
  /// ```
  /// Blog? blog = await Blog().withTrash().find(1);
  /// await blog?.restore();
  /// ```
  Future<bool> restore() async {
    bool events = _eventsOn;
    if (events) {
      try {
        await _fire(ModelEvent.restoring);
      } on CancelModelEvent {
        return false;
      }
    }
    await _thisRecord().update(<String, dynamic>{'deleted_at': null});
    if (events) await _fire(ModelEvent.restored);
    return true;
  }

  /// start ********** events

  /// true when the model class declares an on... hook.
  /// The generator sets it, so models without hooks skip all event work.
  bool get hasModelHooks => false;

  static Map<Type, List<ModelObserver<dynamic>>>? _observers;

  static final Object _quietKey = Object();

  /// add an observer for the model [M]. Observers run in the order
  /// they are added, after the model's own hook.
  ///
  /// ```
  /// Model.observe<User>(UserObserver());
  /// ```
  static void observe<M>(ModelObserver<M> observer) {
    (_observers ??= <Type, List<ModelObserver<dynamic>>>{})
        .putIfAbsent(M, () => <ModelObserver<dynamic>>[])
        .add(observer);
  }

  /// remove the observers of [M], or of every model when [M] is not given
  static void forgetObservers<M>() {
    if (M == dynamic) {
      _observers = null;
    } else {
      _observers?.remove(M);
      if (_observers?.isEmpty == true) _observers = null;
    }
  }

  /// run [callback] without firing model events
  ///
  /// ```
  /// await Model.withoutEvents(() => user.save());
  /// ```
  static Future<R> withoutEvents<R>(FutureOr<R> Function() callback) async {
    return await runZoned(
      callback,
      zoneValues: <Object, Object>{_quietKey: true},
    );
  }

  bool get _eventsOn =>
      (hasModelHooks || _observers?[runtimeType] != null) &&
      Zone.current[_quietKey] != true;

  Future<void> _fire(ModelEvent event) async {
    if (hasModelHooks) await _hook(event);
    List<ModelObserver<dynamic>>? list = _observers?[runtimeType];
    if (list == null) return;
    for (ModelObserver<dynamic> observer in list) {
      await observer.handle(event, this);
    }
  }

  FutureOr<void> _hook(ModelEvent event) {
    switch (event) {
      case ModelEvent.saving:
        return onSaving();
      case ModelEvent.saved:
        return onSaved();
      case ModelEvent.creating:
        return onCreating();
      case ModelEvent.created:
        return onCreated();
      case ModelEvent.updating:
        return onUpdating();
      case ModelEvent.updated:
        return onUpdated();
      case ModelEvent.deleting:
        return onDeleting();
      case ModelEvent.deleted:
        return onDeleted();
      case ModelEvent.restoring:
        return onRestoring();
      case ModelEvent.restored:
        return onRestored();
      case ModelEvent.forceDeleting:
        return onForceDeleting();
      case ModelEvent.forceDeleted:
        return onForceDeleted();
    }
  }

  // ponytail: named on... and not creating/deleted like Laravel,
  // because deleted/created are common column names.
  FutureOr<void> onSaving() {}
  FutureOr<void> onSaved() {}
  FutureOr<void> onCreating() {}
  FutureOr<void> onCreated() {}
  FutureOr<void> onUpdating() {}
  FutureOr<void> onUpdated() {}
  FutureOr<void> onDeleting() {}
  FutureOr<void> onDeleted() {}
  FutureOr<void> onRestoring() {}
  FutureOr<void> onRestored() {}
  FutureOr<void> onForceDeleting() {}
  FutureOr<void> onForceDeleted() {}

  /// end ********** events

  /// Reload eager relationship after new record created/updated.
  /// await Blog().reload()
  Future<void> reload() async {
    await initPreload(<Model<T>>[this]);
  }

  /// support jsonEncode()
  ///
  /// ```
  /// Blog? blog = Blog().find(1);
  /// Map<String, dynamic> m = blog?.toJson();
  /// ```
  Map<String, dynamic> toJson() {
    Map<String, dynamic> data = toMap(removeHiddenField: true);
    for (String h in hidden) {
      data.remove(h);
    }
    return data;
  }

  /// convert model to map
  /// if you have custom select query, use original option with true value
  ///
  /// ```
  /// Blog? blog = Blog().find(1);
  /// Map<String, dynamic> m = blog?.toMap();
  /// Map<String, dynamic> m = blog?.toMap(original: true);
  /// ```
  Map<String, dynamic> toMap({
    bool original = false,
    bool removeHiddenField = false,
    bool removeRelations = false,
  }) {
    if (removeRelations == true) {
      List<String> columns = tableColumns;
      Map<String, dynamic> data = convertToMap(this);
      data.removeWhere((String key, _) => !columns.contains(key));
      return data;
    }
    if (original == true && originalMap.isNotEmpty) {
      return originalMap;
    }
    Map<String, dynamic> data = convertToMap(this);
    setComputedValues(data);
    if (removeHiddenField) {
      for (String h in hidden) {
        data.remove(h);
      }
    }
    return data;
  }

  /// adds the @Computed getters to [map].
  /// the generator overrides it only for models that have them.
  void setComputedValues(Map<String, dynamic> map) {}

  /// start ********** preload

  List<String> get preloadList => <String>[]; // coverage:ignore-line
  List<String> get customPreloadList =>
      _preloads ?? const <String>[]; // coverage:ignore-line

  /// made on the first preload(), most models never call it
  List<String>? _preloads;

  /// the generator overrides these with the relations of the model
  Map<String, Function> get relationsResultMatcher =>
      _resultMatcher ??= <String, Function>{};
  set relationsResultMatcher(Map<String, Function> value) =>
      _resultMatcher = value;
  Map<String, Function>? _resultMatcher;

  Map<String, Function> get relationsQueryMatcher =>
      _queryMatcher ??= <String, Function>{};
  set relationsQueryMatcher(Map<String, Function> value) =>
      _queryMatcher = value;
  Map<String, Function>? _queryMatcher;

  /// preload relationship
  /// ```
  /// Blog blog = await Blog().preload('comments').find(1);
  /// print(blog.comments);
  /// ```
  Model<T> preload(String key) {
    (_preloads ??= <String>[]).add(key);
    return this;
  }

  /// Get relation result
  /// ```
  /// Blog blog = await Blog()find(1);
  /// await blog.$getRelation('comments');
  /// print(blog.comments);
  /// `
  Future<M?> $getRelation<M>(String name) async {
    return await _getRelation(<Model<T>>[this], name) as M;
  }

  /// Get relation query
  /// ```
  /// Blog blog = await Blog()find(1);
  /// Comment comment = blog.related<Comment>('comments');
  /// await comment.get();
  /// `
  M? related<M>(String name) {
    if (relationsQueryMatcher[name] != null) {
      Function funcName = relationsQueryMatcher[name]!;
      return Function.apply(funcName, <dynamic>[
        <Model<T>>[this],
      ]);
    }
    return null;
  }

  Future<void> _getRelation(List<Model<T>> i, String name) async {
    if (relationsResultMatcher[name] != null) {
      Function funcName = relationsResultMatcher[name]!;
      return await Function.apply(funcName, <dynamic>[i]);
    }
  }

  @override
  List<String> getPreload() {
    List<String> list = preloadList;
    List<String>? custom = _preloads;
    if (custom == null && list.isEmpty) return const <String>[];
    return <String>{...list, ...?custom}.toList();
  }

  @override
  Future<void> initPreload(List<Model<T>> list) async {
    List<String> pList = getPreload();
    for (String key in pList) {
      await _getRelation(list, key);
    }
  }

  /// get all records
  /// ```
  /// List<Blog> blogs = await Blog().all();
  /// ```
  @override
  Future<List<T>> all() async {
    return await super.all();
  }

  /// find the record
  /// ```
  /// Blog? blog = await Blog().find(1);
  /// Blog? blog = await Blog().find('name', 'John');
  /// ```
  @override
  Future<T?> find(dynamic arg1, [dynamic arg2]) {
    return super.find(arg1, arg2) as Future<T?>;
  }

  /// create a record
  /// ```
  /// Blog blog = await Blog().create({
  ///   "title" : "Blog title",
  ///   "body" : "Lorem",
  /// });
  /// ````
  ///
  /// When the model has events, create() fills a new model from [data]
  /// and calls save(), so the hooks run. Only @Column fields are saved
  /// then. When a hook cancels, it returns the unsaved model.
  @override
  Future<T> create(Map<String, dynamic> data) async {
    if (!_eventsOn) return await super.insert(data);
    Model<T> model = fromMap(_dateTimesToString(data)) as Model<T>;
    model.debug(_debug);
    if (!await model.save()) return model as T;
    return await super.find(model.tempIdValue);
  }

  /// fromMap() reads dates as strings, like rows from the database
  Map<String, dynamic> _dateTimesToString(Map<String, dynamic> data) {
    return <String, dynamic>{
      for (MapEntry<String, dynamic> e in data.entries)
        e.key: e.value is DateTime
            ? (e.value as DateTime).toIso8601String()
            : e.value,
    };
  }

  /// create a record
  /// ```
  /// Blog blog = await Blog().insert({
  ///   "title" : "Blog title",
  ///   "body" : "Lorem",
  /// });
  /// ````
  @override
  Future<T> insert(Map<String, dynamic> data) async {
    return await create(data);
  }
}
