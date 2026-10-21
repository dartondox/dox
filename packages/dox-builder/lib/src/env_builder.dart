import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:dox_annotation/dox_annotation.dart';
import 'package:source_gen/source_gen.dart';

/// Writes `_$<Class>` for a `@DoxEnv()` class.
///
/// Each getter becomes a final field. `load()` reads every key once, then
/// throws one `EnvException` with all missing or bad keys.
/// - key: `@EnvKey('X')`, or the getter name in UPPER_SNAKE case
/// - a getter with a body is the default (any expression, read only when
///   the key is missing)
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
    String defaults = '_\$${name}Defaults';

    List<_EnvField> fields = <_EnvField>[];
    for (GetterElement getter in element.getters) {
      if (getter.isOriginDeclaration && !getter.isStatic) {
        fields.add(_EnvField.from(getter));
      }
    }

    StringBuffer declarations = StringBuffer();
    StringBuffer params = StringBuffer();
    StringBuffer reads = StringBuffer();
    StringBuffer args = StringBuffer();
    StringBuffer defaultGetters = StringBuffer();
    bool hasDefault = false;

    for (_EnvField f in fields) {
      declarations.writeln('@override\nfinal ${f.type} ${f.name};');
      params.writeln('required this.${f.name},');
      String read = "r.${f.readCall}";
      if (f.hasDefault) {
        hasDefault = true;
        reads.writeln('${f.type} ${f.name} = $read ?? d.${f.name};');
        args.writeln('${f.name}: ${f.name},');
      } else if (f.nullable) {
        reads.writeln('${f.type} ${f.name} = $read;');
        args.writeln('${f.name}: ${f.name},');
      } else {
        reads.writeln("${f.type}? ${f.name} = $read;");
        reads.writeln("r.need('${f.key}');");
        args.writeln('${f.name}: ${f.name}!,');
      }
      if (!f.hasDefault) {
        defaultGetters.writeln(
          '@override\n${f.type} get ${f.name} => '
          "throw StateError('${f.key} has no default');",
        );
      }
    }

    String defaultsClass = hasDefault
        ? '''
/// gives the getter bodies of [$name] (the defaults)
class $defaults extends $name {
  $defaultGetters
}
'''
        : '';
    String defaultsLocal = hasDefault ? '$defaults d = $defaults();' : '';
    String constructor = fields.isEmpty
        ? '$generated._();'
        : '$generated._({$params});';

    return '''
class $generated extends $name {
  $constructor

  $declarations

  /// reads and checks every key once. Throws `EnvException` with all
  /// missing or bad keys.
  static $name load([EnvReader? reader]) {
    EnvReader r = reader ?? EnvReader();
    $defaultsLocal
    $reads
    r.check();
    return $generated._($args);
  }
}

$defaultsClass
''';
  }
}

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
    String typeName = type.getDisplayString();
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
    String k = "'${key.replaceAll("'", r"\'")}'";
    if (type.isDartCoreString) return 'string($k)';
    if (type.isDartCoreInt) return 'integer($k)';
    if (type.isDartCoreDouble) return 'decimal($k)';
    if (type.isDartCoreNum) return 'number($k)';
    if (type.isDartCoreBool) return 'boolean($k)';
    Element? element = type.element;
    if (element is EnumElement) {
      return 'enumByName($k, ${element.displayName}.values)';
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
