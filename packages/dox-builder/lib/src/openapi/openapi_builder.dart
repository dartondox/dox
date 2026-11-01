import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';

import '../schema/json_schema_reader.dart';
import '../util.dart';
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
///
/// Dox finds operations by controller class name, and login schemes by
/// middleware class name. So two controllers (or two `@Security`
/// classes, or two schemas) with one name in two files stop the build
/// with a clear error. A new name like `UserController2` would not match
/// at runtime.
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
    Map<String, ClassElement> securityClasses = <String, ClassElement>{};
    List<AssetId> ids = await buildStep
        .findAssets(Glob('lib/**.dart'))
        .toList();
    // a stable order, so the file does not change between builds
    ids.sort(_byPath);
    for (AssetId id in ids) {
      if (isGenerated(id)) continue;
      // resolving is slow: first a quick look at the text
      String text = await buildStep.readAsString(id);
      if (!mayHave(text, _words)) continue;
      if (!await resolver.isLibrary(id)) continue;
      LibraryElement library = await resolver.libraryFor(id);
      for (LibraryFragment fragment in library.fragments) {
        // generated parts have no routes
        if (fragment.source.uri.path.endsWith('.g.dart')) continue;
        AstNode? unit = await resolver.astNodeFor(fragment, resolve: true);
        unit?.accept(scanner);
      }
      for (ClassElement element in library.classes) {
        if (annotations.has(element, 'DoxController')) {
          controllers.add(element);
        }
        DartObject? secured = annotations.first(element, 'Security');
        if (secured != null) {
          _checkName(securityClasses, element, '@Security classes');
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
    Map<String, ClassElement> controllerNames = <String, ClassElement>{};
    for (ClassElement controller in controllers) {
      _checkName(controllerNames, controller, 'controllers');
    }

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

  /// a library with none of these words has no route, controller or
  /// login scheme
  static const List<String> _words = <String>[
    'route',
    'controller',
    'security',
  ];

  /// stop the build when two classes of one kind have one name
  void _checkName(
    Map<String, ClassElement> seen,
    ClassElement element,
    String what,
  ) {
    String name = element.displayName;
    ClassElement? other = seen[name];
    if (other != null && other != element) {
      throw InvalidGenerationSourceError(
        'Two $what are named $name: in ${other.library.uri} and '
        '${element.library.uri}. The OpenAPI docs find them by name, so '
        'rename one.',
        element: element,
      );
    }
    seen[name] = element;
  }

  static int _byPath(AssetId a, AssetId b) {
    return a.path.compareTo(b.path);
  }
}
