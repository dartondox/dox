import 'package:dox_orm/dox_orm.dart';

import 'keys.dart';

/// local key used by each query, so the result can be matched to owners
final Expando<String> _localKeys = Expando<String>();

/// one to one relationship query
M? hasOne<T, M>(
  List<Model<T>> list,
  Model<M> Function() model, {
  String? foreignKey,
  String? localKey,
  dynamic onQuery,
}) {
  if (list.isEmpty) return null;

  Model<T> owner = list.first;
  localKey = localKey ?? owner.primaryKey;
  foreignKey = foreignKey ?? owner.foreignKeyName;

  List<dynamic> ids = relationKeys(list, localKey);

  Model<M> m = model().debug(owner.shouldDebug);
  m.connection ??= owner.connection;

  if (relationSubquery) {
    m.whereRaw(subqueryMatch(m, '${m.tableName}.$foreignKey', owner, localKey));
  } else {
    m.select('*, $foreignKey as _owner_id').whereIn(foreignKey, ids);
  }

  if (onQuery != null) {
    m = onQuery(m);
  }
  _localKeys[m] = localKey;
  return m as M;
}

/// get result of one to one relationship query
/// the result is keyed by each owner primary key (tempIdValue).
Future<Map<String, M>> getHasOne<T, M>(dynamic q, List<Model<T>> list) async {
  if (q == null) return <String, M>{}; // coverage:ignore-line
  List<M> results = await q.get();

  Map<String, M> ret = <String, M>{};

  /// filter matched values with local id value
  for (M r in results) {
    String ownerId = (r as Model<M>).originalMap['_owner_id'].toString();
    ret[ownerId] = r;
  }

  /// match each owner by its local key
  String? localKey = _localKeys[q];
  Map<String, M> byOwner = <String, M>{};
  for (Model<T> i in list) {
    dynamic key = localKey == null ? i.tempIdValue : relationKey(i, localKey);
    M? value = ret[key.toString()];
    if (value != null) {
      byOwner[i.tempIdValue.toString()] = value;
    }
  }
  return byOwner;
}
