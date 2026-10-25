import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';

import '../schema/json_schema_reader.dart';
import 'annotation_reader.dart';
import 'controller_reader.dart';
import 'registry_writer.dart';
import 'route_scanner.dart';
import 'security_data.dart';

/// Writes `lib/generated/openapi.g.dart` with the OpenAPI docs of the app.
///
/// It reads every library in `lib/`:
/// - `Route.get(...)` and `Route.resource(...)` calls give the
///   controller classes and which method each route calls,
/// - classes with `@DoxController()` are added too,
/// - each controller method gives one operation,
/// - classes with `@Security(...)` (middleware) give login schemes.
///
/// Nothing is written when the package has no controllers and no
/// `@Security` classes.
class DoxOpenApiBuilder implements Builder {
  const DoxOpenApiBuilder();

  static const String output = 'lib/generated/openapi.g.dart';

  @override
  Map<String, List<String>> get buildExtensions {
    return const <String, List<String>>{
      r'$lib$': <String>['generated/openapi.g.dart'],
    };
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    Resolver resolver = buildStep.resolver;
    RouteScanner scanner = RouteScanner();
    AnnotationReader annotations = const AnnotationReader();
    List<ClassElement> controllers = <ClassElement>[];
    Map<String, SecurityData> security = <String, SecurityData>{};
    await for (AssetId id in buildStep.findAssets(Glob('lib/**.dart'))) {
      if (id.path == output || !await resolver.isLibrary(id)) continue;
      LibraryElement library = await resolver.libraryFor(id);
      for (LibraryFragment fragment in library.fragments) {
        AstNode? unit = await resolver.astNodeFor(fragment, resolve: true);
        unit?.accept(scanner);
      }
      for (ClassElement element in library.classes) {
        if (annotations.has(element, 'DoxController')) {
          controllers.add(element);
        }
        DartObject? secured = annotations.first(element, 'Security');
        if (secured != null) {
          security[element.displayName] = SecurityData.read(
            element.displayName,
            secured,
          );
        }
      }
    }
    for (RouteCall call in scanner.calls) {
      if (!controllers.contains(call.controller)) {
        controllers.add(call.controller);
      }
    }
    if (controllers.isEmpty && security.isEmpty) return;

    JsonSchemaReader types = JsonSchemaReader(AstLoader(resolver));
    ControllerReader reader = ControllerReader(types);
    List<OperationData> operations = <OperationData>[];
    for (ClassElement controller in controllers) {
      operations.addAll(await reader.read(controller));
    }
    String code = const RegistryWriter().write(
      operations,
      scanner.calls,
      types.components,
      security,
    );
    DartFormatter formatter = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    );
    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, output),
      formatter.format(code),
    );
  }
}
