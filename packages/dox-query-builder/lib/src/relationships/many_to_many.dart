import 'package:dox_query_builder/dox_query_builder.dart';

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

  localKey = localKey ?? local.primaryKey;
  relatedKey = relatedKey ?? related.primaryKey;

  String localTable = local.tableName;
  String relatedTable = related.tableName;

  // @todo: sort by alphabet to join table;
  pivotTable = pivotTable ?? _sortTableByAlphabet(relatedTable, localTable);

  pivotForeignKey = pivotForeignKey ?? '${localTable}_id';
  pivotRelatedForeignKey = pivotRelatedForeignKey ?? '${relatedTable}_id';

  List<String> ids = list.map((Model<T> i) {
    Map<String, dynamic> map = i.toMap();
    return map[localKey].toString();
  }).toList();

  QueryBuilder<M> q = related
      .debug(local.shouldDebug)
      .select('$relatedTable.*, $pivotTable.$pivotForeignKey as _owner_id')
      .leftJoin(pivotTable, '$pivotTable.$pivotRelatedForeignKey',
          '$relatedTable.$relatedKey')
      .whereIn('$pivotTable.$pivotForeignKey', ids);

  if (onQuery != null) {
    q = onQuery(q);
  }
  return q as M;
}

/// sort two table alphabetically
/// blog and category , blog_category
/// song and artist, artist_song
String _sortTableByAlphabet(String firstTable, String secondTable) {
  List<String> tables = <String>[firstTable, secondTable];
  tables.sort();
  return '${tables[0]}_${tables[1]}';
}

/// get result of many to many relationship query
Future<Map<String, List<M>>> getManyToMany<T, M>(
  dynamic q,
  List<Model<T>> list,
) async {
  if (q == null) return <String, List<M>>{}; // coverage:ignore-line
  List<M> results = await q.get();

  Map<String, List<M>> ret = <String, List<M>>{};

  /// filter matched values with local id value
  for (M r in results) {
    Map<String, dynamic> map = (r as Model<M>).toMap(original: true);
    String ownerId = map['_owner_id'].toString();
    if (ret[ownerId] == null) {
      ret[ownerId] = <M>[];
    }
    ret[ownerId]?.add(r);
  }

  /// to prevent result null instead return empty list
  for (Model<T> i in list) {
    ret[i.tempIdValue.toString()] = ret[i.tempIdValue.toString()] ?? <M>[];
  }

  return ret;
}
