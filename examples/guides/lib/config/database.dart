import 'package:dox_orm/dox_orm.dart';
import 'package:my_app/config/app.dart';
import 'package:my_app/config/env.dart';

DatabaseConfig databaseConfig = DatabaseConfig(
  // DATABASE_URL from .env or the environment, the same one that
  // `dox migrate` reads. When it is set, it wins over the DB_* keys.
  url: env.databaseUrl,
  connection: env.dbConnection,
  connections: <String, ConnectionConfig>{
    'postgres': ConnectionConfig(
      driver: Driver.postgres,
      host: env.dbHost,
      port: env.dbPort ?? 5432,
      user: env.dbUsername,
      password: env.dbPassword,
      database: env.dbName,
      // print every query on your machine only
      debug: appConfig.isDevelopment,
    ),
    'sqlite': ConnectionConfig(
      driver: Driver.sqlite,
      database: env.dbName,
      debug: appConfig.isDevelopment,
    ),
  },
);
