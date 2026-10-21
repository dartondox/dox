import 'package:dox_orm/dox_orm.dart';

import '../utils/logger.dart';
import 'table.column.dart';

abstract class TableSharedMixin {
  final List<TableColumn> columns = <TableColumn>[];
  String tableName = '';
  bool debug = false;
  DBDriver get dbDriver;
  Logger get logger;
}
