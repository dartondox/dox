import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dox_annotation/dox_annotation.dart';
import 'package:source_gen/source_gen.dart';

import 'openapi/dart_literal.dart';
import 'util.dart';

/// Writes `_$<Class>` for a `@DoxEnv()` class.
///
/// `load()` reads every key once, then throws one `EnvException` with all
/// missing or bad keys.
/// - key: `@EnvKey('X')` (also through a const variable), or the getter
///   name in UPPER_SNAKE case (`dbURL` => `DB_URL`)
/// - a getter with a body is the default (any expression, used only when
///   the key is missing). The body runs on the loaded env, so it may use
///   other getters: `appEnv == 'development'` sees the real `APP_ENV`.
///   `load()` works out every default once, so a default that throws stops
///   the app at startup.
/// - a nullable getter with no body is optional
/// - other getters with no body are required
/// - only getters of the class itself are read. Getters from a superclass
///   or a mixin are not. An instance field is a build error.
class DoxEnvBuilder extends GeneratorForAnnotation<DoxEnv> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@DoxEnv can only be used on a class.',
        element: element,
      );
    }
    String name = element.displayName;
    String generated = '_\$$name';

    List<_EnvField> fields = <_EnvField>[];
    for (GetterElement getter in element.getters) {
      if (getter.isStatic) continue;
      if (!getter.isOriginDeclaration) {
        // the getter of a field: a field can never be read from the env
        throw InvalidGenerationSourceError(
          'Env class $name has the field "${getter.displayName}". '
          'Use a getter: `String get ${getter.displayName};` (required) or '
          '`String get ${getter.displayName} => ...;` (with a default).',
          element: getter,
        );
      }
      fields.add(_EnvField.from(getter));
    }

    StringBuffer declarations = StringBuffer();
    StringBuffer params = StringBuffer();
    List<String> inits = <String>[];
    StringBuffer reads = StringBuffer();
    StringBuffer args = StringBuffer();
    StringBuffer touches = StringBuffer();

    for (_EnvField f in fields) {
      String read = "\$r.${f.readCall}";
      String nullableType = f.nullable ? f.type : '${f.type}?';
      reads.writeln('$nullableType ${f.name} = $read;');
      if (f.hasDefault) {
        // `_$x` holds the raw env value. `x` is `late` so the getter body
        // runs on this object and sees the loaded values of other keys.
        String raw = '_\$${f.name}';
        declarations.writeln(
          'final $nullableType $raw;\n'
          '@override\n'
          'late final ${f.type} ${f.name} = $raw ?? super.${f.name};',
        );
        params.writeln('required $nullableType ${f.name},');
        inits.add('$raw = ${f.name}');
        args.writeln('${f.name}: ${f.name},');
        touches.writeln('\$env.${f.name};');
      } else {
        declarations.writeln('@override\nfinal ${f.type} ${f.name};');
        params.writeln('required this.${f.name},');
        if (f.nullable) {
          args.writeln('${f.name}: ${f.name},');
        } else {
          reads.writeln('\$r.need(${_literal.string(f.key)});');
          args.writeln('${f.name}: ${f.name}!,');
        }
      }
    }

    String loopMessage = _literal.string(
      'A default of $name reads the global `env`. Use the getter directly: '
      'write `appEnv`, not `env.appEnv`.',
    );
    String initList = inits.isEmpty ? '' : ' : ${inits.join(', ')}';
    String constructor = fields.isEmpty
        ? '$generated._();'
        : '$generated._({$params})$initList;';

    return '''
class $generated extends $name {
  $constructor

  $declarations

  /// true while [load] runs. A default that reads the global `env` calls
  /// [load] again, and would loop until the stack overflows.
  static bool _\$\$loading = false;

  /// reads and checks every key once. Throws `EnvException` with all
  /// missing or bad keys. Then works out every default once, so a default
  /// that throws stops the app here, at startup.
  static $name load([EnvReader? \$reader]) {
    if (_\$\$loading) {
      throw StateError($loopMessage);
    }
    _\$\$loading = true;
    try {
      EnvReader \$r = \$reader ?? EnvReader();
      $reads
      \$r.check();
      $generated \$env = $generated._($args);
      $touches
      return \$env;
    } finally {
      _\$\$loading = false;
    }
  }
}
''';
  }
}

const DartLiteral _literal = DartLiteral();

/// one getter of the env class
class _EnvField {
  final String name;
  final String key;
  final String type;
  final bool nullable;
  final bool hasDefault;
  final String readCall;

  _EnvField(
    this.name,
    this.key,
    this.type,
    this.nullable,
    this.hasDefault,
    this.readCall,
  );

  factory _EnvField.from(GetterElement getter) {
    String name = getter.displayName;
    String key = _envKey(getter) ?? upperSnake(name);
    DartType type = getter.returnType;
    bool nullable = type.nullabilitySuffix == NullabilitySuffix.question;
    String typeName = typeCode(type, getter.library);
    return _EnvField(
      name,
      key,
      typeName,
      nullable,
      !getter.isAbstract,
      _readCall(getter, type, key),
    );
  }

  static String? _envKey(GetterElement getter) {
    // by the type of the value, so `@EnvKey('X')` and a const variable
    // that holds an `EnvKey` both work
    for (ElementAnnotation m in getter.metadata.annotations) {
      DartObject? value = m.computeConstantValue();
      if (value?.type?.element?.displayName == 'EnvKey') {
        return value!.getField('name')?.toStringValue();
      }
    }
    return null;
  }

  static String _readCall(GetterElement getter, DartType type, String key) {
    String k = _literal.string(key);
    if (type.isDartCoreString) return 'string($k)';
    if (type.isDartCoreInt) return 'integer($k)';
    if (type.isDartCoreDouble) return 'decimal($k)';
    if (type.isDartCoreNum) return 'number($k)';
    if (type.isDartCoreBool) return 'boolean($k)';
    Element? element = type.element;
    if (element is EnumElement) {
      return 'enumByName($k, '
          '${prefixOf(element, getter.library)}${element.displayName}.values)';
    }
    bool core = element?.library?.isDartCore ?? false;
    if (core && element?.displayName == 'Uri') return 'uri($k)';
    if (core && element?.displayName == 'Duration') return 'duration($k)';
    if (type is InterfaceType &&
        type.isDartCoreList &&
        type.typeArguments.single.isDartCoreString &&
        type.typeArguments.single.nullabilitySuffix == NullabilitySuffix.none) {
      return 'list($k)';
    }
    throw InvalidGenerationSourceError(
      'Env getter "${getter.displayName}" has type '
      '${type.getDisplayString()}. Use String, int, double, num, bool, '
      'Uri, Duration, an enum or List<String>.',
      element: getter,
    );
  }
}

/// `appName` => `APP_NAME`, `s3Bucket` => `S3_BUCKET`.
/// A run of capitals is one word: `dbURL` => `DB_URL`,
/// `httpURLPath` => `HTTP_URL_PATH`.
String upperSnake(String name) {
  StringBuffer out = StringBuffer();
  for (int i = 0; i < name.length; i++) {
    String char = name[i];
    if (i > 0 && _isUpper(char)) {
      String before = name[i - 1];
      bool afterLower = _isLower(before) || _isDigit(before);
      // the last capital of a run starts the next word: `URLPath`
      bool endsRun =
          _isUpper(before) && i + 1 < name.length && _isLower(name[i + 1]);
      if (afterLower || endsRun) out.write('_');
    }
    out.write(char.toUpperCase());
  }
  return out.toString();
}

bool _isUpper(String char) => char != char.toLowerCase();

bool _isLower(String char) => char != char.toUpperCase();

bool _isDigit(String char) => '0123456789'.contains(char);
