import '../casts.dart';

class Column {
  final String? name;
  final Function? beforeSave;
  final Function? beforeGet;

  /// changes the value between the database and Dart, see [Cast]
  final Cast<dynamic>? cast;

  const Column({this.name, this.beforeSave, this.beforeGet, this.cast});
}

/// Marks a static method of a model as a query scope.
/// The method takes the query first, and can take more arguments.
/// The generator adds it as a method on the query of the model.
///
/// ```
/// @Scope()
/// static QueryBuilder<User> active(QueryBuilder<User> q) =>
///     q.where('active', true);
///
/// await User().active().get();
/// ```
///
/// `global: true` adds it to every query of the model. Remove it with
/// `withoutGlobalScope('name')` or `withoutGlobalScopes()`.
class Scope {
  final bool global;

  const Scope({this.global = false});
}

/// Adds a getter to toJson() and toMap(). It is never a table column.
///
/// ```
/// @Computed()
/// String get fullName => '$firstName $lastName'; // key: full_name
///
/// @Computed(name: 'display')
/// String get displayName => name ?? '';
/// ```
class Computed {
  /// json key, the default is the getter name in snake_case
  final String? name;

  const Computed({this.name});
}

class HasOne {
  final Type model;
  final String? foreignKey;
  final String? localKey;
  final Function? onQuery;
  final bool? eager;

  const HasOne(
    this.model, {
    this.foreignKey,
    this.localKey,
    this.onQuery,
    this.eager,
  });
}

class HasMany {
  final Type model;
  final String? foreignKey;
  final String? localKey;
  final Function? onQuery;
  final bool? eager;

  const HasMany(
    this.model, {
    this.foreignKey,
    this.localKey,
    this.onQuery,
    this.eager,
  });
}

class BelongsTo {
  final Type model;
  final String? foreignKey;
  final String? localKey;
  final Function? onQuery;
  final bool? eager;

  const BelongsTo(
    this.model, {
    this.foreignKey,
    this.localKey,
    this.onQuery,
    this.eager,
  });
}

class ManyToMany {
  final Type model;
  final Function? onQuery;
  final bool? eager;

  /// id column on artist table
  final String? localKey;

  /// id column on song table
  final String? relatedKey;

  /// artist_id column on related table
  final String? pivotForeignKey;

  /// artist_id column on related table
  final String? pivotRelatedForeignKey;

  /// song_artist table
  final String? pivotTable;

  const ManyToMany(
    this.model, {
    this.eager,
    this.onQuery,
    this.localKey,
    this.relatedKey,
    this.pivotForeignKey,
    this.pivotRelatedForeignKey,
    this.pivotTable,
  });
}
