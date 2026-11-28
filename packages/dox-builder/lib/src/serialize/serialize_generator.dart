import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../dto/dto_model.dart';
import '../dto/dto_writer.dart';
import '../schema/json_schema_reader.dart';
import '../util.dart';
import 'serialize_reader.dart';
import 'serializer_writer.dart';

/// Writes the JSON writer of each `@Serialize()` class of a library into
/// its `.g.dart` part.
///
/// A class that gets no writer keeps its map (`toJson()` of a
/// serializer), and the build logs a warning with the reason. Its part
/// still gets a comment, so the `part` line of the file always finds a
/// file.
class DoxSerializeGenerator extends Generator {
  const DoxSerializeGenerator({this.reader = const DtoReader()});

  final DtoReader reader;

  @override
  Future<String?> generate(LibraryReader library, BuildStep buildStep) async {
    List<ClassElement> classes = <ClassElement>[
      for (ClassElement element in library.classes)
        if (reader.isSerialize(element)) element,
    ];
    if (classes.isEmpty) return null;
    SerializeReader serialize = SerializeReader(
      AstLoader(buildStep.resolver),
      reader: reader,
    );
    bool sees = seesAnnotationClass(
      library.element.firstFragment,
      'SerializeWriter',
    );
    List<String> parts = <String>[];
    for (ClassElement element in classes) {
      String name = element.displayName;
      String? problem;
      if (!sees) {
        problem = 'the dox_annotation of the app has no SerializeWriter';
      } else if (DtoReader.isSerializer(element)) {
        SerializerRead read = await serialize.serializer(element);
        SerializerPlan? plan = read.plan;
        if (plan != null) {
          parts.add(await SerializerWriter(plan, serialize).write());
          continue;
        }
        problem = read.problem;
      } else {
        problem = reader.plainProblem(element);
        if (problem == null) {
          List<String> skipped = <String>[];
          DtoClass dto = reader.readPlain(element, skipped);
          for (String field in skipped) {
            log.warning(
              '@Serialize() $name: the field $field is not final, so it is '
              'not in the JSON.',
            );
          }
          parts.add(DtoWriter.serialize(dto).writeSerialize());
          continue;
        }
      }
      log.warning(
        '@Serialize() $name gets no fast JSON writer: $problem. It keeps '
        'its toJson().',
      );
      parts.add(
        '// $name: no JSON writer, ${problem?.replaceAll('\n', ' ')}.\n',
      );
    }
    // a value checked for its class at run time can not be null
    return '// ignore_for_file: type=lint, unnecessary_null_comparison\n\n'
        '${parts.join('\n')}';
  }
}
