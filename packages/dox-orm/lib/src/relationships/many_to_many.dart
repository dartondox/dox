import 'package:dox_orm/dox_orm.dart';

import 'keys.dart';

/// local key used by each query, so the result can be matched to owners
final Expando<String> _localKeys = Expando<String>();

/// many to many relationship query
M? manyToMany<T, M>(
  List<Model<T>> list,
  Model<M> Function() model, {
  dynamic onQuery,
  String? localKey,
  String? relatedKey,
  String? pivotForeignKey,
  String? pivotRelatedForeignKey,
  String? pivotTable,
}) {
  if (list.isEmpty) return null;

  Model<T> local = list.first;
  Model<M> related = model();
  related.connection ??= local.connection;

  localKey = localKey ?? local.primaryKey;
  relatedKey = relatedKey ?? related.primaryKey;

  String relatedTable = related.tableName;

  /// the defaults use the model names, like Laravel:
  /// Artist and Song give artist_song, artist_id and song_id
  String localName = local.helper.tableNameOf(local.runtimeType);
  String relatedName = related.helper.tableNameOf(related.runtimeType);
  pivotTable = pivotTable ?? _sortTableByAlphabet(relatedName, localName);

  pivotForeignKey = pivotForeignKey ?? local.foreignKeyName;
  pivotRelatedForeignKey = pivotRelatedForeignKey ?? related.foreignKeyName;

  List<dynamic> ids = relationKeys(list, localKey);

  QueryBuilder<M> q = related
      .debug(local.shouldDebug)
      .select('$relatedTable.*, $pivotTable.$pivotForeignKey as _owner_id')
      .leftJoin(
        pivotTable,
        '$pivotTable.$pivotRelatedForeignKey',
        '$relatedTable.$relatedKey',
      )
      .whereIn('$pivotTable.$pivotForeignKey', ids);

  if (onQuery != null) {
    q = onQuery(q);
  }
  _localKeys[q] = localKey;
  return q as M;
}

/// sort two names alphabetically
/// blog and category , blog_category
/// song and artist, artist_song
String _sortTableByAlphabet(String firstTable, String secondTable) {
  List<String> tables = <String>[firstTable, secondTable];
  tables.sort();
  return '${tables[0]}_${tables[1]}';
}

/// get result of many to many relationship query
/// the result is keyed by each owner primary key (tempIdValue).
Future<Map<String, List<M>>> getManyToMany<T, M>(
  dynamic q,
  List<Model<T>> list,
) async {
  if (q == null) return <String, List<M>>{}; // coverage:ignore-line
  List<M> results = await q.get();

  Map<String, List<M>> ret = <String, List<M>>{};

  /// filter matched values with local id value
  for (M r in results) {
    String ownerId = (r as Model<M>).originalMap['_owner_id'].toString();
    if (ret[ownerId] == null) {
      ret[ownerId] = <M>[];
    }
    ret[ownerId]?.add(r);
  }

  /// match each owner by its local key, and use an empty list
  /// instead of null when there is no result
  String? localKey = _localKeys[q];
  Map<String, List<M>> byOwner = <String, List<M>>{};
  for (Model<T> i in list) {
    dynamic key = localKey == null ? i.tempIdValue : relationKey(i, localKey);
    byOwner[i.tempIdValue.toString()] = ret[key.toString()] ?? <M>[];
  }
  return byOwner;
}
