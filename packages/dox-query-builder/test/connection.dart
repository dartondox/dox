import 'dart:io';

import 'package:dox_query_builder/dox_query_builder.dart';

import 'mysql.dart';
import 'postgres.dart';

Future<void> initQueryBuilder() async {
  SqlQueryBuilder.initialize(
    database: await poolConnection(),
    driver: getDriver(),
  );
}

Future<dynamic> poolConnection() {
  if (Platform.environment['DRIVER'] == 'mysql') {
    return mysqlConnection();
  } else {
    return postgresConnection();
  }
}

Driver getDriver() {
  if (Platform.environment['DRIVER'] == 'mysql') {
    return Driver.mysql;
  } else {
    return Driver.postgres;
  }
}
