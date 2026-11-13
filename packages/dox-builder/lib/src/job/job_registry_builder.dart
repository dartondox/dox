import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';

/// One `@Job()` class.
class JobEntry {
  JobEntry(this.element, this.library, this.name);

  final ClassElement element;

  /// the import of the class, like `package:app/jobs/welcome.dart`
  final String library;

  /// the name saved with each queued job
  final String name;

  /// the constructor parameters, saved with the job
  final List<FormalParameterElement> params = <FormalParameterElement>[];

  String get className => element.displayName;
}

/// Writes `lib/generated/jobs.g.dart`: a `jobRegistry` with every
/// `@Job()` class of the app, and the code to save and load each one.
/// Give it to the app: `QueueConfig(jobs: jobRegistry)`.
///
/// It runs only in an app that depends on dox_queue. When the app can
/// import dox_mailer too, the mail jobs of `Mail.queue()` are added.
///
/// The parameters of the unnamed constructor are saved. Each one needs
/// a field or getter of the same name, and a JSON type. The build stops
/// with a clear message when one does not fit.
class JobRegistryBuilder implements Builder {
  const JobRegistryBuilder();

  static const String output = 'lib/generated/jobs.g.dart';

  static final AssetId _queue = AssetId('dox_queue', 'lib/dox_queue.dart');
  static final AssetId _mailer = AssetId('dox_mailer', 'lib/dox_mailer.dart');

  /// the builder of dox_queue 3.1. That dox_queue writes the file itself.
  static final AssetId _oldBuilder = AssetId('dox_queue', 'lib/builder.dart');

  @override
  Map<String, List<String>> get buildExtensions {
    return const <String, List<String>>{
      r'$lib$': <String>['generated/jobs.g.dart'],
    };
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    // an app without dox_queue gets no jobs.g.dart: it would not compile
    if (!await buildStep.canRead(_queue)) return;
    if (!await _dependsOnQueue(buildStep)) return;
    // dox_queue 3.1 has its own builder for this file. Two builders of one
    // file stop build_runner, so leave it to that one.
    if (await buildStep.canRead(_oldBuilder)) return;
    Resolver resolver = buildStep.resolver;
    List<JobEntry> entries = <JobEntry>[];
    List<AssetId> ids = await buildStep
        .findAssets(Glob('lib/**.dart'))
        .toList();
    ids.sort(_byPath);
    for (AssetId id in ids) {
      if (id.path.endsWith('.g.dart')) continue;
      // fast skip: only files that may have @Job() get resolved
      if (!(await buildStep.readAsString(id)).contains('Job(')) continue;
      if (!await resolver.isLibrary(id)) continue;
      LibraryElement library = await resolver.libraryFor(id);
      String uri = id.uri.toString();
      for (ClassElement element in library.classes) {
        JobEntry? entry = _entry(element, uri);
        if (entry != null) entries.add(entry);
      }
    }
    _checkNames(entries);
    String code = JobRegistryWriter(
      entries,
      mailJobs: await _hasMailJobs(buildStep),
    ).write();
    DartFormatter formatter = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    );
    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, output),
      formatter.format(code),
    );
  }

  /// true when dox_queue is in `dependencies` or `dev_dependencies` of
  /// the app, not only a dependency of a dependency (like dox_mailer).
  /// When the build can not read the pubspec, it trusts [canRead].
  Future<bool> _dependsOnQueue(BuildStep buildStep) async {
    AssetId pubspec = AssetId(buildStep.inputId.package, 'pubspec.yaml');
    if (!await buildStep.canRead(pubspec)) return true;
    return hasDirectDependency(
      await buildStep.readAsString(pubspec),
      'dox_queue',
    );
  }

  /// true when [name] is a key under `dependencies:` or
  /// `dev_dependencies:` of the pubspec text [yaml]
  // ponytail: a line scan, not a YAML parser; pubspecs list one key per line
  static bool hasDirectDependency(String yaml, String name) {
    String? section;
    RegExp key = RegExp('^\\s+${RegExp.escape(name)}\\s*:');
    for (String line in yaml.split('\n')) {
      if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
      if (!line.startsWith(' ') && !line.startsWith('\t')) {
        section = line.split(':').first.trim();
        continue;
      }
      bool deps = section == 'dependencies' || section == 'dev_dependencies';
      if (deps && key.hasMatch(line)) return true;
    }
    return false;
  }

  /// true when the app can import a dox_mailer that has the mail jobs.
  /// An older dox_mailer (3.1) has them in dox_queue, so they are not
  /// added.
  Future<bool> _hasMailJobs(BuildStep buildStep) async {
    if (!await buildStep.canRead(_mailer)) return false;
    LibraryElement library = await buildStep.resolver.libraryFor(_mailer);
    return library.exportNamespace.get2('SendQueuedMail') != null &&
        library.exportNamespace.get2('SendEncryptedQueuedMail') != null;
  }

  JobEntry? _entry(ClassElement element, String library) {
    DartObject? job = _jobAnnotation(element);
    if (job == null) return null;
    String className = element.displayName;
    String where = '$className ($library)';
    if (!_isJob(element)) {
      throw StateError('@Job() on $where: the class must extend DoxJob.');
    }
    if (element.isAbstract) {
      throw StateError('@Job() on $where: an abstract class can not be made.');
    }
    if (element.typeParameters.isNotEmpty) {
      throw StateError(
        '@Job() on $where: a job class can not have type parameters.',
      );
    }
    if (element.isPrivate) {
      throw StateError('@Job() on $where: a job class can not be private.');
    }
    ConstructorElement? constructor = element.unnamedConstructor;
    if (constructor == null) {
      throw StateError(
        '@Job() on $where: the class needs an unnamed constructor.',
      );
    }
    String name = job.getField('name')?.toStringValue() ?? className;
    if (name.startsWith('dox_queue:')) {
      throw StateError(
        '@Job() on $where: the name "$name" starts with "dox_queue:". '
        'That start is kept for the built-in jobs. Use another name.',
      );
    }
    JobEntry entry = JobEntry(element, library, name);
    for (FormalParameterElement param in constructor.formalParameters) {
      String field = param.displayName;
      String at = '$where, parameter "$field"';
      if (field.startsWith('_')) {
        throw StateError(
          '$at: a private parameter can not be saved. Make it public.',
        );
      }
      if (element.lookUpGetter(name: field, library: element.library) == null) {
        throw StateError(
          '$at: the class needs a field or getter "$field", so the job can '
          'be saved.',
        );
      }
      String? problem = _typeProblem(param.type);
      if (problem != null) {
        throw StateError(
          '$at: the type ${param.type.getDisplayString()} can not be saved '
          '($problem). Use int, double, num, String, bool, DateTime, an '
          'enum, or a List or Map<String, ...> of these. Save an id and '
          'load the object in handle().',
        );
      }
      entry.params.add(param);
    }
    return entry;
  }

  /// the `@Job()` annotation of dox_queue, or null
  DartObject? _jobAnnotation(ClassElement element) {
    for (ElementAnnotation annotation in element.metadata.annotations) {
      DartObject? value = annotation.computeConstantValue();
      DartType? type = value?.type;
      if (value != null &&
          type is InterfaceType &&
          type.element.name == 'Job' &&
          _fromQueue(type.element)) {
        return value;
      }
    }
    return null;
  }

  /// true when [element] extends the dox_queue class `DoxJob`
  bool _isJob(ClassElement element) {
    for (InterfaceType type in element.allSupertypes) {
      if (type.element.name == 'DoxJob' && _fromQueue(type.element)) {
        return true;
      }
    }
    return false;
  }

  bool _fromQueue(Element element) {
    String? uri = element.library?.uri.toString();
    return uri != null && uri.startsWith('package:dox_queue/');
  }

  /// why [type] can not be saved, or null when it can
  String? _typeProblem(DartType type) {
    if (type is DynamicType) return null;
    if (type is! InterfaceType) return 'not a class type';
    if (type.isDartCoreInt ||
        type.isDartCoreDouble ||
        type.isDartCoreNum ||
        type.isDartCoreString ||
        type.isDartCoreBool ||
        type.isDartCoreObject ||
        isDateTime(type) ||
        type.element is EnumElement) {
      return null;
    }
    if (type.isDartCoreList) return _typeProblem(type.typeArguments.first);
    if (type.isDartCoreMap) {
      if (!type.typeArguments.first.isDartCoreString) {
        return 'map keys must be String';
      }
      return _typeProblem(type.typeArguments.last);
    }
    return '${type.element.displayName} is not a JSON type';
  }

  /// stop the build when two jobs have one name
  void _checkNames(List<JobEntry> entries) {
    Map<String, JobEntry> seen = <String, JobEntry>{};
    for (JobEntry entry in entries) {
      JobEntry? other = seen[entry.name];
      if (other != null) {
        throw StateError(
          'Two jobs are named "${entry.name}": ${other.className} '
          '(${other.library}) and ${entry.className} (${entry.library}). '
          'Rename one, or set @Job(name: ...).',
        );
      }
      seen[entry.name] = entry;
    }
  }

  static bool isDateTime(DartType type) {
    return type is InterfaceType &&
        type.element.name == 'DateTime' &&
        type.element.library.isDartCore;
  }

  static int _byPath(AssetId a, AssetId b) {
    return a.path.compareTo(b.path);
  }
}

/// Writes the code of `lib/generated/jobs.g.dart`.
class JobRegistryWriter {
  JobRegistryWriter(this.entries, {this.mailJobs = false});

  final List<JobEntry> entries;

  /// add the mail jobs of dox_mailer, so a worker reads them without
  /// `Mail.configure()`
  final bool mailJobs;

  /// import uri -> prefix (`i1`, `i2`, ...)
  final Map<String, String> _prefixes = <String, String>{};

  String write() {
    StringBuffer body = StringBuffer();
    StringBuffer list = StringBuffer();
    for (int i = 0; i < entries.length; i++) {
      JobEntry entry = entries[i];
      String type = '${_prefix(entry.library)}.${entry.className}';
      list.writeln("JobCodec('${entry.name}', $type, _encode$i, _decode$i),");
      _writeEncode(body, entry, type, i);
      _writeDecode(body, entry, type, i);
    }
    if (mailJobs) {
      String mail = _prefix('package:dox_mailer/dox_mailer.dart');
      list
        ..writeln('$mail.SendQueuedMail.codec,')
        ..writeln('$mail.SendEncryptedQueuedMail.codec,');
    }
    StringBuffer out = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
      ..writeln('// Made by dox_builder. Run `dart run build_runner build`.')
      ..writeln('// ignore_for_file: type=lint')
      ..writeln()
      ..writeln("import 'package:dox_queue/dox_queue.dart';");
    for (MapEntry<String, String> import in _prefixes.entries) {
      out.writeln("import '${import.key}' as ${import.value};");
    }
    out
      ..writeln()
      ..writeln('/// Every `@Job()` class of the app.')
      ..writeln('/// Use it in `QueueConfig(jobs: jobRegistry)`.')
      ..writeln('const JobRegistry jobRegistry = JobRegistry(<JobCodec>[')
      ..write(list)
      ..writeln(']);')
      ..write(body);
    return out.toString();
  }

  void _writeEncode(StringBuffer out, JobEntry entry, String type, int i) {
    out
      ..writeln()
      ..writeln('Map<String, Object?> _encode$i(DoxJob job) {');
    // a job with no fields has no value to read, and an unused variable
    // is a warning in the app
    if (entry.params.isNotEmpty) {
      out.writeln('$type value = job as $type;');
    }
    out.writeln('return <String, Object?>{');
    for (FormalParameterElement param in entry.params) {
      String name = param.displayName;
      out.writeln("'$name': value.$name,");
    }
    out
      ..writeln('};')
      ..writeln('}');
  }

  void _writeDecode(StringBuffer out, JobEntry entry, String type, int i) {
    List<String> args = <String>[];
    for (FormalParameterElement param in entry.params) {
      String name = param.displayName;
      String value = decode("data['$name']", param.type, 1);
      args.add(param.isNamed ? '$name: $value' : value);
    }
    out
      ..writeln()
      ..writeln('DoxJob _decode$i(Map<String, Object?> data) {')
      ..writeln('return $type(${args.join(', ')});')
      ..writeln('}');
  }

  /// the code that turns the JSON value [expr] into a [type]
  String decode(String expr, DartType type, int depth) {
    bool nullable = type.nullabilitySuffix == NullabilitySuffix.question;
    if (type is! InterfaceType || type.isDartCoreObject) {
      return type is InterfaceType && !nullable ? '$expr as Object' : expr;
    }
    String q = nullable ? '?' : '';
    if (type.isDartCoreInt) return '($expr as num$q)$q.toInt()';
    if (type.isDartCoreDouble) return '($expr as num$q)$q.toDouble()';
    if (type.isDartCoreNum) return '$expr as num$q';
    if (type.isDartCoreString) return '$expr as String$q';
    if (type.isDartCoreBool) return '$expr as bool$q';
    String value;
    String v = 'e$depth';
    if (JobRegistryBuilder.isDateTime(type)) {
      value = 'DateTime.parse($expr as String)';
    } else if (type.element is EnumElement) {
      value =
          '${typeCode(type, nullable: false)}.values.byName($expr as String)';
    } else if (type.isDartCoreList) {
      DartType item = type.typeArguments.first;
      value =
          '<${typeCode(item)}>[for (Object? $v in $expr as List<Object?>) '
          '${decode(v, item, depth + 1)}]';
    } else {
      DartType item = type.typeArguments.last;
      value =
          '<String, ${typeCode(item)}>{for (MapEntry<String, Object?> $v in '
          '($expr as Map<String, Object?>).entries) '
          '$v.key: ${decode('$v.value', item, depth + 1)}}';
    }
    return nullable ? '($expr == null ? null : $value)' : value;
  }

  /// [type] as code, with the import prefix of an enum
  String typeCode(DartType type, {bool? nullable}) {
    bool isNullable =
        nullable ?? type.nullabilitySuffix == NullabilitySuffix.question;
    String q = isNullable ? '?' : '';
    if (type is! InterfaceType) return 'dynamic';
    String name = type.element.displayName;
    if (type.element is EnumElement) {
      return '${_prefix(type.element.library.uri.toString())}.$name$q';
    }
    if (type.typeArguments.isEmpty) return '$name$q';
    String args = <String>[
      for (DartType arg in type.typeArguments) typeCode(arg),
    ].join(', ');
    return '$name<$args>$q';
  }

  String _prefix(String library) {
    return _prefixes.putIfAbsent(library, _nextPrefix);
  }

  String _nextPrefix() {
    return 'i${_prefixes.length + 1}';
  }
}
