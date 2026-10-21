import 'dart:io';

import 'package:dox_app/config/app.dart';
import 'package:dox_core/dox_core.dart';

/// write the OpenAPI document of the app routes:
/// `dart run bin/openapi.dart [output dir]` (default storage/openapi).
/// `dox openapi:generate` runs this file.
Future<void> main(List<String> args) async {
  Dox().initialize(appConfig);
  String dir = args.isEmpty ? 'storage/openapi' : args.first;
  List<File> files = await Dox().writeOpenApi(dir);
  for (File file in files) {
    print('written ${file.path}');
  }
  exit(0);
}
