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
/// - key: `@EnvKey('X')`, or the getter name in UPPER_SNAKE case
/// - a getter with a body is the default (any expression, used only when
///   the key is missing). The body runs on the loaded env, so it may use
///   other getters: `appEnv == 'development'` sees the real `APP_ENV`.
///   `load()` works out every default once, so a default that throws stops
///   the app at startup.
/// - a nullable getter with no body is optional
/// - other getters with no body are required
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
      if (getter.isOriginDeclaration && !getter.isStatic) {
        fields.add(_EnvField.from(getter));
      }
    }

    StringBuffer declarations = StringBuffer();
    StringBuffer params = StringBuffer();
    List<String> inits = <String>[];
    StringBuffer reads = StringBuffer();
    StringBuffer args = StringBuffer();
    StringBuffer touches = StringBuffer();

    for (_EnvField f in fields) {
      String read = "r.${f.readCall}";
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
          reads.writeln('r.need(${_literal.string(f.key)});');
          args.writeln('${f.name}: ${f.name}!,');
        }
      }
    }

    String initList = inits.isEmpty ? '' : ' : ${inits.join(', ')}';
    String constructor = fields.isEmpty
        ? '$generated._();'
        : '$generated._({$params})$initList;';

    return '''
class $generated extends $name {
  $constructor

  $declarations

  /// reads and checks every key once. Throws `EnvException` with all
  /// missing or bad keys. Then works out every default once, so a default
  /// that throws stops the app here, at startup.
  static $name load([EnvReader? reader]) {
    EnvReader r = reader ?? EnvReader();
    $reads
    r.check();
    $generated \$env = $generated._($args);
    $touches
    return \$env;
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
    for (ElementAnnotation m in getter.metadata.annotations) {
      Element? e = m.element;
      String? annotation = e is ConstructorElement
          ? e.enclosingElement.displayName
          : e?.displayName;
      if (annotation == 'EnvKey') {
        return m.computeConstantValue()?.getField('name')?.toStringValue();
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

/// `appName` => `APP_NAME`, `s3Bucket` => `S3_BUCKET`
String upperSnake(String name) {
  StringBuffer out = StringBuffer();
  for (int i = 0; i < name.length; i++) {
    String char = name[i];
    bool upper = char != char.toLowerCase();
    if (upper && i > 0) out.write('_');
    out.write(char.toUpperCase());
  }
  return out.toString();
}
