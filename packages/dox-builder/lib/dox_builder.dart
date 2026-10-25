library;

import 'package:build/build.dart';
import 'package:dox_builder/src/container/container_builder.dart';
import 'package:dox_builder/src/dox_builder.dart';
import 'package:dox_builder/src/dto/dto_generator.dart';
import 'package:dox_builder/src/dto/dto_registry_builder.dart';
import 'package:dox_builder/src/env_builder.dart';
import 'package:dox_builder/src/openapi/openapi_builder.dart';
import 'package:source_gen/source_gen.dart';

export 'src/container/container_builder.dart';
export 'src/dto/dto_generator.dart';
export 'src/dto/dto_model.dart';
export 'src/dto/dto_registry_builder.dart';
export 'src/dto/dto_writer.dart';
export 'src/schema/dto_schema.dart';
export 'src/schema/json_schema_reader.dart';
export 'src/schema/model_schema.dart';

/// Models (`@DoxModel`), DTOs (`@Dto`) and env classes (`@DoxEnv`) go into
/// the `.g.dart` part.
Builder buildDoxModel(BuilderOptions options) => SharedPartBuilder(<Generator>[
  DoxModelBuilder(),
  const DoxDtoGenerator(),
  DoxEnvBuilder(),
], 'dox_model_generator');

/// Writes `lib/generated/dtos.g.dart` with every DTO of the app.
Builder buildDoxDtos(BuilderOptions options) => const DoxDtoRegistryBuilder();

/// Writes `lib/generated/openapi.g.dart` from the routes, controllers and models.
Builder buildDoxOpenApi(BuilderOptions options) => const DoxOpenApiBuilder();

/// Writes `lib/generated/container.g.dart`: the `@Inject()` classes, routers,
/// services and model binders of the app.
Builder buildDoxContainer(BuilderOptions options) {
  return const DoxContainerBuilder();
}
