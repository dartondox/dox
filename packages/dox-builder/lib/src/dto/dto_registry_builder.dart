import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';

import 'dto_model.dart';

/// Writes `lib/dtos.g.dart`: one list of every `@Dto` in `lib/`.
/// Give it to the app: `AppConfig(dtos: dtos)`. Dox finds a DTO by its
/// type with it (no `dart:mirrors`).
///
/// Nothing is written when the package has no DTOs.
class DoxDtoRegistryBuilder implements Builder {
  const DoxDtoRegistryBuilder({this.reader = const DtoReader()});

  final DtoReader reader;

  static const String output = 'lib/dtos.g.dart';

  @override
  Map<String, List<String>> get buildExtensions {
    return const <String, List<String>>{
      r'$lib$': <String>['dtos.g.dart'],
    };
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    Resolver resolver = buildStep.resolver;
    Map<String, String> found = <String, String>{};
    List<String> imports = <String>[];
    String schemaImport = 'package:dox_validation/dox_validation.dart';
    bool schemaFound = false;
    List<AssetId> ids = await buildStep
        .findAssets(Glob('lib/**.dart'))
        .toList();
    ids.sort(_byPath);
    for (AssetId id in ids) {
      if (id.path == output || id.path.endsWith('.g.dart')) continue;
      if (!await resolver.isLibrary(id)) continue;
      LibraryElement library = await resolver.libraryFor(id);
      bool used = false;
      for (ClassElement element in library.classes) {
        if (!reader.isDto(element)) continue;
        String name = element.displayName;
        String? other = found[name];
        if (other != null) {
          throw StateError(
            'Two @Dto classes are named $name: in $other and ${id.path}. '
            'Dox finds DTOs by name, so rename one.',
          );
        }
        found[name] = id.path;
        used = true;
      }
      if (!used) continue;
      imports.add(id.uri.toString());
      if (!schemaFound) {
        String? uri = _schemaImport(library);
        if (uri != null) {
          schemaImport = uri;
          schemaFound = true;
        }
      }
    }
    if (found.isEmpty) return;
    StringBuffer out = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
      ..writeln('// Made by dox_builder. Run `dart run build_runner build`.')
      ..writeln('// ignore_for_file: type=lint')
      ..writeln()
      ..writeln("import '$schemaImport';");
    for (String uri in imports) {
      out.writeln("import '$uri';");
    }
    out
      ..writeln()
      ..writeln('/// Every DTO of the app. Use it in `AppConfig(dtos: dtos)`.')
      ..writeln('const List<DtoSchema<Object>> dtos = <DtoSchema<Object>>[');
    List<String> names = found.keys.toList()..sort();
    for (String name in names) {
      out.writeln('\$${name}Dto,');
    }
    out.writeln('];');
    DartFormatter formatter = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    );
    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, output),
      formatter.format(out.toString()),
    );
  }

  /// The import of [library] that gives `DtoSchema`, like
  /// `package:dox_core/dox_core.dart`.
  String? _schemaImport(LibraryElement library) {
    for (LibraryImport import in library.firstFragment.libraryImports) {
      LibraryElement? imported = import.importedLibrary;
      if (imported == null || import.prefix != null) continue;
      if (imported.exportNamespace.get2('DtoSchema') != null) {
        return imported.uri.toString();
      }
    }
    return null;
  }

  static int _byPath(AssetId a, AssetId b) {
    return a.path.compareTo(b.path);
  }
}
