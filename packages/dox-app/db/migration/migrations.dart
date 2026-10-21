// Made by `dox make:migration` and the `dox migration:*` commands.
// Do not edit, it is made again from the files in this folder.
import 'package:dox_migration/dox_migration.dart';

import '2023_07_16_131915229_create_blog_table.dart' as m1;
import '2023_07_16_131922862_create_blog_category.dart' as m2;
import '2023_07_16_131933100_create_category_table.dart' as m3;
import '2023_07_16_131937700_create_user_table.dart' as m4;

/// all Dart migrations of db/migration, sorted by name
final List<MigrationEntry> migrations = <MigrationEntry>[
  MigrationEntry(
    '2023_07_16_131915229_create_blog_table',
    m1.CreateBlogTable(),
  ),
  MigrationEntry(
    '2023_07_16_131922862_create_blog_category',
    m2.CreateBlogCategory(),
  ),
  MigrationEntry(
    '2023_07_16_131933100_create_category_table',
    m3.CreateCategoryTable(),
  ),
  MigrationEntry(
    '2023_07_16_131937700_create_user_table',
    m4.CreateUserTable(),
  ),
];
