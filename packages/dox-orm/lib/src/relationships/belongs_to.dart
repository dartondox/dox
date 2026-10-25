import 'package:dox_orm/dox_orm.dart';

import 'keys.dart';

/// (foreign key, local key) used by each query, so the result can be
/// matched to the children
final Expando<(String, String)> _keys = Expando<(String, String)>();

/// belongs to relationship query
M? belongsTo<T, M>(
  List<Model<T>> list,
  Model<M> Function() model, {
  String? foreignKey,
  String? localKey,
  dynamic onQuery,
}) {
  if (list.isEmpty) return null;
  if (relationSubquery) {
    throw UnsupportedError(
      'withCount() works with hasOne, hasMany and manyToMany relations.',
    );
  }

  Model<T> foreign = list.first;
  Model<M> owner = model().debug(foreign.shouldDebug);
  owner.connection ??= foreign.connection;
  localKey = localKey ?? owner.primaryKey;
  foreignKey = foreignKey ?? owner.foreignKeyName;

  /// each owner once: no join to the children, so an owner with many
  /// children is one row, not one row per child
  List<dynamic> ids = relationKeys(list, foreignKey);

  owner.whereIn('${owner.tableName}.$localKey', ids);

  if (onQuery != null) {
    owner = onQuery(owner);
  }
  _keys[owner] = (foreignKey, localKey);
  return owner as M;
}

/// get result from belongs to relationship query
/// the result is keyed by each child primary key (tempIdValue).
Future<Map<String, M>> getBelongsTo<T, M>(
  dynamic q,
  List<Model<T>> list,
) async {
  if (q == null) return <String, M>{}; // coverage:ignore-line
  List<M> results = await q.get();
  var (String foreignKey, String localKey) = _keys[q]!;

  /// owners by their local key value
  Map<String, M> owners = <String, M>{};
  for (M r in results) {
    owners[relationKey(r as Model<M>, localKey).toString()] = r;
  }

  /// match each child by its foreign key
  Map<String, M> ret = <String, M>{};
  for (Model<T> i in list) {
    M? owner = owners[relationKey(i, foreignKey).toString()];
    if (owner != null) {
      ret[i.tempIdValue.toString()] = owner;
    }
  }
  return ret;
}
