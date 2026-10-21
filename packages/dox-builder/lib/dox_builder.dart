library;

import 'package:build/build.dart';
import 'package:dox_builder/src/dox_builder.dart';
import 'package:dox_builder/src/openapi/openapi_builder.dart';
import 'package:source_gen/source_gen.dart';

export 'src/schema/dto_schema.dart';
export 'src/schema/json_schema_reader.dart';
export 'src/schema/model_schema.dart';

Builder buildDoxModel(BuilderOptions options) =>
    SharedPartBuilder([DoxModelBuilder()], 'dox_model_generator');

/// Writes `lib/openapi.g.dart` from the routes, controllers and models.
Builder buildDoxOpenApi(BuilderOptions options) => const DoxOpenApiBuilder();
