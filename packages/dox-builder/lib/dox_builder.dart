library;

import 'package:build/build.dart';
import 'package:dox_builder/src/dox_builder.dart';
import 'package:dox_builder/src/dto/dto_generator.dart';
import 'package:dox_builder/src/dto/dto_registry_builder.dart';
import 'package:dox_builder/src/openapi/openapi_builder.dart';
import 'package:source_gen/source_gen.dart';

export 'src/dto/dto_generator.dart';
export 'src/dto/dto_model.dart';
export 'src/dto/dto_registry_builder.dart';
export 'src/dto/dto_writer.dart';
export 'src/schema/dto_schema.dart';
export 'src/schema/json_schema_reader.dart';
export 'src/schema/model_schema.dart';

/// Models (`@DoxModel`) and DTOs (`@Dto`) go into the `.g.dart` part.
Builder buildDoxModel(BuilderOptions options) => SharedPartBuilder(<Generator>[
  DoxModelBuilder(),
  const DoxDtoGenerator(),
], 'dox_model_generator');

/// Writes `lib/dtos.g.dart` with every DTO of the app.
Builder buildDoxDtos(BuilderOptions options) => const DoxDtoRegistryBuilder();

/// Writes `lib/openapi.g.dart` from the routes, controllers and models.
Builder buildDoxOpenApi(BuilderOptions options) => const DoxOpenApiBuilder();
