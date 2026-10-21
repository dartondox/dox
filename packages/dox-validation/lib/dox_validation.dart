/// Typed input for Dart: DTO classes with generated checks, and
/// fluent schemas like Zod for input you only know at runtime.
///
/// ```dart
/// import 'package:dox_validation/dox_validation.dart';
///
/// ObjectSchema user = v.object(<String, Schema<Object?>>{
///   'email': v.string().email(),
///   'age': v.coerce.int().min(18),
/// });
/// Map<String, dynamic> data = user.parse(input);
/// ```
library;

import 'src/validator.dart';

export 'src/constants/default_messages.dart';
export 'src/constants/issue_codes.dart';
export 'src/constants/patterns.dart';
export 'src/constants/schema_constants.dart';
export 'src/core/data_path.dart';
export 'src/core/fluent_schema.dart';
export 'src/core/issue.dart';
export 'src/core/json_schema_tools.dart';
export 'src/core/message_resolver.dart';
export 'src/core/parse_result.dart';
export 'src/core/parse_state.dart';
export 'src/core/refine_rules.dart';
export 'src/core/rule.dart';
export 'src/core/schema.dart';
export 'src/core/sentinels.dart';
export 'src/core/validation_exception.dart';
export 'src/dto/dto_annotations.dart';
export 'src/dto/dto_schema.dart';
export 'src/dto/dto_state.dart';
export 'src/dto/file_types.dart';
export 'src/dto/maybe.dart';
export 'src/rules/built_in_rule.dart';
export 'src/rules/collection_rules.dart';
export 'src/rules/number_rules.dart';
export 'src/rules/string_rules.dart';
export 'src/schemas/list_schema.dart';
export 'src/schemas/map_schema.dart';
export 'src/schemas/number_schemas.dart';
export 'src/schemas/object_schema.dart';
export 'src/schemas/scalar_schemas.dart';
export 'src/schemas/string_schema.dart';
export 'src/schemas/union_schema.dart';
export 'src/schemas/wrapper_schemas.dart';
export 'src/standard/standard_schema.dart';
export 'src/validator.dart';

/// The default [Validator]. Use it like `v.string().email()`.
const Validator v = Validator();
