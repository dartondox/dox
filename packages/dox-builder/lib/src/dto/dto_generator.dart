import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../schema/json_schema_reader.dart';
import 'dto_model.dart';
import 'dto_writer.dart';

/// Writes `$<Name>Dto` for each `@Dto` class of a library, into its
/// `.g.dart` part.
class DoxDtoGenerator extends Generator {
  const DoxDtoGenerator({this.reader = const DtoReader()});

  final DtoReader reader;

  @override
  Future<String?> generate(LibraryReader library, BuildStep buildStep) async {
    List<String> parts = <String>[];
    DtoFlagsReader flags = DtoFlagsReader(reader);
    for (ClassElement element in library.classes) {
      if (!reader.isDto(element)) continue;
      DtoClass dto = reader.read(element);
      reader.check(dto);
      JsonSchemaReader types = JsonSchemaReader(
        AstLoader(buildStep.resolver),
        refPrefix: r'#/$defs/',
      );
      await types.of(element.thisType, nullable: false);
      Map<String, dynamic> schema = <String, dynamic>{
        ...?types.components[dto.name],
      };
      Map<String, dynamic> defs = <String, dynamic>{
        for (MapEntry<String, Map<String, dynamic>> entry
            in types.components.entries)
          if (entry.key != dto.name) entry.key: entry.value,
      };
      if (defs.isNotEmpty) schema[r'$defs'] = defs;
      parts.add(DtoWriter(dto, flags, schema).write(flags.of(element)));
    }
    if (parts.isEmpty) return null;
    return '// ignore_for_file: type=lint\n\n${parts.join('\n')}';
  }
}

/// Finds the [DtoFlags] of DTO classes, nested DTOs too. Each class is
/// read once.
class DtoFlagsReader implements DtoFlagsSource {
  DtoFlagsReader(this.reader);

  final DtoReader reader;
  final Map<ClassElement, DtoFlags> _done = <ClassElement, DtoFlags>{};

  static const DtoFlags _none = DtoFlags(
    checks: false,
    checksAsync: false,
    async: false,
  );

  @override
  DtoFlags flagsOf(DtoType type) {
    DartType dart = type.type;
    InterfaceElement? element = dart is InterfaceType ? dart.element : null;
    return element is ClassElement ? of(element) : _none;
  }

  /// The flags of [element].
  DtoFlags of(ClassElement element) {
    DtoFlags? known = _done[element];
    if (known != null) return known;
    // a placeholder, so DTOs that point to each other do not loop
    _done[element] = _none;
    DtoClass dto = reader.read(element);
    bool checks = dto.validate != null;
    bool checksAsync = dto.validateIsAsync;
    bool async = false;
    for (DtoField field in dto.fields) {
      for (DtoRule rule in field.rules) {
        async = async || rule.isAsync;
      }
      DtoType type = field.type;
      DtoType? nested = type.kind == DtoKind.dto
          ? type
          : type.item?.kind == DtoKind.dto
          ? type.item
          : null;
      if (nested == null) continue;
      DtoFlags inner = flagsOf(nested);
      checks = checks || inner.checks;
      checksAsync = checksAsync || inner.checksAsync;
      async = async || inner.async;
    }
    DtoFlags flags = DtoFlags(
      checks: checks,
      checksAsync: checksAsync,
      async: async,
    );
    _done[element] = flags;
    return flags;
  }
}
