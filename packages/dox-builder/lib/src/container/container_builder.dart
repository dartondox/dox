import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';

import '../openapi/annotation_reader.dart';

/// How a class goes into the container.
enum EntryKind { inject, router, service }

/// One class that goes into the container.
class ContainerEntry {
  ContainerEntry(this.element, this.kind, this.library, {required this.shared});

  final ClassElement element;
  final EntryKind kind;

  /// the import of the class, like `package:app/user.dart`
  final String library;

  /// one instance per isolate (true) or one per `get` (false)
  final bool shared;

  /// the constructor arguments
  final List<ContainerArg> args = <ContainerArg>[];

  /// the classes the constructor needs from the container
  final List<ContainerEntry> needs = <ContainerEntry>[];

  String get name => element.displayName;
}

/// One constructor argument: a class from the container, or null.
class ContainerArg {
  const ContainerArg(this.label, this.need);

  /// `name: ` for a named parameter, else empty
  final String label;

  /// the class to get from the container. null passes `null`.
  final ContainerEntry? need;
}

/// One `@DoxModel` class: a route param of its type is found by its key.
class ModelEntry {
  ModelEntry(this.element, this.library, this.keyType);

  final ClassElement element;
  final String library;

  /// `int`, `String`, ... from `@DoxModel(primaryKeyType:)`
  final String keyType;

  String get name => element.displayName;
}

/// Writes `lib/generated/container.g.dart`: one function that puts every class of
/// the app into the Dox container. Give it to the app:
/// `AppConfig(container: registerContainer)`.
///
/// It reads every library in `lib/` and finds:
/// - classes with `@Inject()`,
/// - classes that extend `Router` (their routes are registered at start),
/// - classes that implement `DoxService` (their `setup()` runs at start),
/// - classes with `@DoxModel()` (route model binding).
///
/// Constructor parameters come from the container, by type. The build
/// stops with a clear message for a parameter the container can not
/// give, and for a dependency cycle.
///
/// Nothing is written when the package has none of these classes.
class DoxContainerBuilder implements Builder {
  const DoxContainerBuilder();

  static const String output = 'lib/generated/container.g.dart';

  static const AnnotationReader _annotations = AnnotationReader();

  @override
  Map<String, List<String>> get buildExtensions {
    return const <String, List<String>>{
      r'$lib$': <String>['generated/container.g.dart'],
    };
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    Resolver resolver = buildStep.resolver;
    List<ContainerEntry> entries = <ContainerEntry>[];
    List<ModelEntry> models = <ModelEntry>[];
    List<AssetId> ids = await buildStep
        .findAssets(Glob('lib/**.dart'))
        .toList();
    ids.sort(_byPath);
    for (AssetId id in ids) {
      if (id.path == output || id.path.endsWith('.g.dart')) continue;
      if (!await resolver.isLibrary(id)) continue;
      LibraryElement library = await resolver.libraryFor(id);
      String uri = id.uri.toString();
      for (ClassElement element in library.classes) {
        ContainerEntry? entry = _entry(element, uri);
        if (entry != null) entries.add(entry);
        ModelEntry? model = _model(element, uri);
        if (model != null) models.add(model);
      }
    }
    if (entries.isEmpty && models.isEmpty) return;
    for (ContainerEntry entry in entries) {
      _readConstructor(entry, entries);
    }
    _checkCycles(entries);
    _warnSameNames(entries);
    String code = ContainerWriter(entries, models).write();
    DartFormatter formatter = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    );
    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, output),
      formatter.format(code),
    );
  }

  ContainerEntry? _entry(ClassElement element, String library) {
    DartObject? inject = _annotations.first(element, 'Inject');
    bool router = _isA(element, 'Router');
    bool service = _isA(element, 'DoxService');
    if (inject == null && (element.isAbstract || (!router && !service))) {
      return null;
    }
    String name = element.displayName;
    if (element.isAbstract) {
      throw StateError(
        '@Inject() on $name ($library): an abstract class can not be made. '
        'Put @Inject() on a class that implements it.',
      );
    }
    if (element.typeParameters.isNotEmpty) {
      throw StateError(
        '@Inject() on $name ($library): a generic class can not be in the '
        'container. Make a class without type parameters.',
      );
    }
    EntryKind kind = router
        ? EntryKind.router
        : service
        ? EntryKind.service
        : EntryKind.inject;
    bool shared =
        kind != EntryKind.inject ||
        (inject?.getField('singleton')?.toBoolValue() ?? true);
    return ContainerEntry(element, kind, library, shared: shared);
  }

  ModelEntry? _model(ClassElement element, String library) {
    DartObject? model = _annotations.first(element, 'DoxModel');
    if (model == null || element.isAbstract) return null;
    DartType? key = model.getField('primaryKeyType')?.toTypeValue();
    String keyType = key is InterfaceType ? key.element.displayName : 'int';
    return ModelEntry(element, library, keyType);
  }

  /// true when [element] extends or implements the dox_core class [name]
  bool _isA(ClassElement element, String name) {
    for (InterfaceType type in element.allSupertypes) {
      InterfaceElement other = type.element;
      if (other.displayName != name) continue;
      String uri = other.library.uri.toString();
      if (uri.startsWith('package:dox_core/')) return true;
    }
    return false;
  }

  /// fill [ContainerEntry.args] and [ContainerEntry.needs]
  void _readConstructor(ContainerEntry entry, List<ContainerEntry> all) {
    ConstructorElement? constructor = entry.element.unnamedConstructor;
    if (constructor == null) {
      throw StateError(
        '${entry.name} (${entry.library}) needs an unnamed constructor to be '
        'in the container.',
      );
    }
    for (FormalParameterElement param in constructor.formalParameters) {
      DartType type = param.type;
      ContainerEntry? need = _find(type, all);
      String label = param.isNamed ? '${param.displayName}: ' : '';
      if (need != null) {
        entry.needs.add(need);
        entry.args.add(ContainerArg(label, need));
        continue;
      }
      // an optional parameter keeps its default
      if (param.isOptional) continue;
      if (type.nullabilitySuffix == NullabilitySuffix.question) {
        entry.args.add(ContainerArg(label, null));
        continue;
      }
      throw StateError(
        '${entry.name} (${entry.library}) needs a '
        '${type.getDisplayString()} for its parameter "${param.displayName}", '
        'but no class of that type is in the container. Add @Inject() above '
        'that class, or make the parameter optional or nullable.',
      );
    }
  }

  ContainerEntry? _find(DartType type, List<ContainerEntry> all) {
    if (type is! InterfaceType || type.typeArguments.isNotEmpty) return null;
    for (ContainerEntry entry in all) {
      if (entry.element == type.element) return entry;
    }
    return null;
  }

  /// stop the build when a class needs itself, through other classes
  void _checkCycles(List<ContainerEntry> entries) {
    Set<ContainerEntry> done = <ContainerEntry>{};
    for (ContainerEntry entry in entries) {
      _visit(entry, <ContainerEntry>[], done);
    }
  }

  void _visit(
    ContainerEntry entry,
    List<ContainerEntry> path,
    Set<ContainerEntry> done,
  ) {
    if (done.contains(entry)) return;
    int start = path.indexOf(entry);
    if (start >= 0) {
      String chain = <String>[
        for (ContainerEntry e in path.sublist(start)) e.name,
        entry.name,
      ].join(' -> ');
      throw StateError(
        'Dependency cycle in the container: $chain. A class can not need '
        'itself. Move the shared code into a new class that both use.',
      );
    }
    path.add(entry);
    for (ContainerEntry need in entry.needs) {
      _visit(need, path, done);
    }
    path.removeLast();
    done.add(entry);
  }

  /// two classes with one name work (each import has a prefix), but Dox
  /// can not tell them apart from a handler parameter type
  void _warnSameNames(List<ContainerEntry> entries) {
    Map<String, ContainerEntry> seen = <String, ContainerEntry>{};
    for (ContainerEntry entry in entries) {
      ContainerEntry? other = seen[entry.name];
      if (other != null) {
        log.warning(
          'Two classes in the container are named ${entry.name}: in '
          '${other.library} and ${entry.library}. Use the typed route style '
          '(Route.get<${entry.name}>(...)) for them, and do not use them as '
          'handler parameters. Or rename one.',
        );
      }
      seen[entry.name] = entry;
    }
  }

  static int _byPath(AssetId a, AssetId b) {
    return a.path.compareTo(b.path);
  }
}

/// Writes the code of `lib/generated/container.g.dart`.
class ContainerWriter {
  ContainerWriter(this.entries, this.models);

  final List<ContainerEntry> entries;
  final List<ModelEntry> models;

  /// import uri -> prefix (`i1`, `i2`, ...)
  final Map<String, String> _prefixes = <String, String>{};

  /// the type of [entry] in the generated code, like `i1.UserService`
  String typeOf(ContainerEntry entry) {
    return '${_prefix(entry.library)}.${entry.name}';
  }

  String write() {
    for (ContainerEntry entry in entries) {
      _prefix(entry.library);
    }
    for (ModelEntry model in models) {
      _prefix(model.library);
    }
    StringBuffer out = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
      ..writeln('// Made by dox_builder. Run `dart run build_runner build`.')
      ..writeln('// ignore_for_file: type=lint')
      ..writeln()
      ..writeln("import 'package:dox_core/dox_core.dart';");
    for (MapEntry<String, String> import in _prefixes.entries) {
      out.writeln("import '${import.key}' as ${import.value};");
    }
    out
      ..writeln()
      ..writeln('/// Puts every class of the app into the container: the')
      ..writeln('/// `@Inject()` classes, routers, services and model binders.')
      ..writeln('/// Use it in `AppConfig(container: registerContainer)`.')
      ..writeln('void registerContainer(IocContainer c) {');
    for (ContainerEntry entry in entries) {
      _writeEntry(out, entry);
    }
    for (ModelEntry model in models) {
      _writeModel(out, model);
    }
    out.writeln('}');
    return out.toString();
  }

  void _writeEntry(StringBuffer out, ContainerEntry entry) {
    String type = typeOf(entry);
    String method = switch (entry.kind) {
      EntryKind.router => 'router',
      EntryKind.service => 'service',
      EntryKind.inject => entry.shared ? 'singleton' : 'factory',
    };
    List<String> values = <String>[
      for (ContainerArg arg in entry.args)
        arg.need == null
            ? '${arg.label}null'
            : '${arg.label}c.get<${typeOf(arg.need!)}>()',
    ];
    String args = values.join(', ');
    out.writeln('c.$method<$type>((IocContainer c) => $type($args));');
  }

  void _writeModel(StringBuffer out, ModelEntry model) {
    String type = '${_prefixes[model.library]}.${model.name}';
    switch (model.keyType) {
      case 'int':
        out.writeln(
          'c.bindModel<$type>((String id) {'
          'int? key = int.tryParse(id);'
          'if (key == null) return null;'
          'return $type().find(key);'
          '});',
        );
      default:
        out.writeln('c.bindModel<$type>((String id) => $type().find(id));');
    }
  }

  String _prefix(String library) {
    return _prefixes.putIfAbsent(library, _nextPrefix);
  }

  String _nextPrefix() {
    return 'i${_prefixes.length + 1}';
  }
}
