import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import '../openapi/annotation_reader.dart';
import '../util.dart';

/// What kind of value a DTO field (or a list item) holds.
enum DtoKind {
  string,
  integer,
  decimal,
  number,
  boolean,
  date,
  enumName,
  file,
  dto,
  list,
  map,

  /// `Map<String, dynamic>`: must be an object, values not checked
  anyMap,

  /// `Object?`, `dynamic`: not checked
  any,
}

/// The type of a field, or of a list item / map value.
class DtoType {
  DtoType(this.kind, this.type, {this.item, this.enumNames = const []});

  final DtoKind kind;

  /// The Dart type, as written in the code.
  final DartType type;

  /// The item type of a list, the value type of a map.
  final DtoType? item;

  /// The value names of an enum.
  final List<String> enumNames;

  bool get nullable {
    return type.nullabilitySuffix == NullabilitySuffix.question ||
        type is DynamicType;
  }

  /// The type in code, like `List<String>` or `int?`.
  String get code {
    return type.getDisplayString();
  }

  /// The type in code without `?`.
  String get nonNullCode {
    String text = code;
    return text.endsWith('?') ? text.substring(0, text.length - 1) : text;
  }

  /// The class name of a nested DTO or an enum.
  String get name {
    DartType value = type;
    return value is InterfaceType ? value.element.displayName : code;
  }

  /// `true` for the types that have a plain value (not a list or map).
  bool get isScalar {
    return kind != DtoKind.list &&
        kind != DtoKind.map &&
        kind != DtoKind.dto &&
        kind != DtoKind.anyMap &&
        kind != DtoKind.any;
  }
}

/// One rule annotation on a field.
class DtoRule {
  DtoRule(this.name, this.value, this.source, {this.custom = false});

  /// The class name, like `Length`.
  final String name;

  /// The constant value of the annotation.
  final DartObject value;

  /// The annotation as a Dart expression, like `const Slug()`.
  final String source;

  /// A `Rule<T>` class of the app (not a built-in annotation).
  final bool custom;

  /// `true` for an `AsyncRule<T>` (like `@Unique`): it runs last.
  bool isAsync = false;

  /// `true` when the rule checks each list item (not the list itself).
  bool onItems = false;

  String? stringField(String field) {
    return value.getField(field)?.toStringValue();
  }

  int? intField(String field) {
    return value.getField(field)?.toIntValue();
  }

  num? numField(String field) {
    DartObject? object = value.getField(field);
    return object?.toIntValue() ?? object?.toDoubleValue();
  }

  /// The `message:` of the annotation.
  String? get message {
    return stringField('message');
  }
}

/// One field of a DTO.
class DtoField {
  DtoField({
    required this.element,
    required this.name,
    required this.key,
    required this.type,
    required this.maybe,
    required this.defaultCode,
    required this.positional,
  });

  final FieldElement element;

  /// The Dart name.
  final String name;

  /// The input key, like `first_name`.
  final String key;

  /// The value type (for `Maybe<T>`: the `T`).
  final DtoType type;

  /// `true` for a `Maybe<T>` field.
  final bool maybe;

  /// The default value in code, or null.
  final String? defaultCode;

  /// `true` when the constructor parameter is positional.
  final bool positional;

  final List<DtoRule> rules = <DtoRule>[];
  bool trim = false;

  /// 0 as is, 1 lower case, 2 upper case
  int textCase = 0;
  bool allowEmpty = false;

  /// The `///` doc comment.
  String? get doc {
    return element.documentationComment;
  }

  bool get hasDefault {
    return defaultCode != null;
  }

  /// Required: not nullable and no default.
  bool get required {
    return !type.nullable && !hasDefault;
  }

  /// The type of the field in code, like `Maybe<String?>`.
  String get fieldCode {
    return element.type.getDisplayString();
  }
}

/// One `@Dto` class, read from the code.
class DtoClass {
  DtoClass(this.element);

  final ClassElement element;
  final List<DtoField> fields = <DtoField>[];

  /// Fields in the order of the constructor parameters.
  final List<DtoField> parameters = <DtoField>[];
  String source = 'auto';
  bool strict = false;
  Map<String, String> messages = <String, String>{};

  /// The `validate(DtoErrors errors)` method, or null.
  MethodElement? validate;

  /// `true` when [validate] returns a `Future`.
  bool validateIsAsync = false;

  /// Problems found. The generator stops with them.
  final List<String> errors = <String>[];

  String get name {
    return element.displayName;
  }
}

/// Reads `@Dto` classes. This is the one place that knows the field
/// keys, the types and the rules of a DTO. The DTO generator and the
/// OpenAPI docs both use it, so both use the same keys.
class DtoReader {
  const DtoReader({this.annotations = const AnnotationReader()});

  final AnnotationReader annotations;

  static const Set<String> textRules = <String>{
    'Length',
    'MinLength',
    'MaxLength',
    'Email',
    'Url',
    'Uuid',
    'Ip',
    'Regex',
    'StartsWith',
    'EndsWith',
    'Alpha',
    'AlphaNumeric',
    'AlphaDash',
  };

  static const Set<String> numberRules = <String>{
    'Min',
    'Max',
    'Range',
    'Positive',
    'GreaterThan',
    'LessThan',
  };

  static const Set<String> listRules = <String>{
    'MinItems',
    'MaxItems',
    'UniqueItems',
  };

  static const Set<String> dateRules = <String>{'After', 'Before'};

  static const Set<String> fileRules = <String>{'MaxSize', 'Mimes', 'Image'};

  static const Set<String> valueRules = <String>{'In', 'NotIn'};

  static const Set<String> textChanges = <String>{
    'Trim',
    'Lowercase',
    'Uppercase',
    'AllowEmpty',
  };

  static final Set<String> builtIn = <String>{
    ...textRules,
    ...numberRules,
    ...listRules,
    ...dateRules,
    ...fileRules,
    ...valueRules,
  };

  /// True when [element] has `@Dto()`.
  bool isDto(Element element) {
    return annotations.has(element, 'Dto');
  }

  /// The input key of [field]: `@Name`, else the Dart name in snake_case
  /// (or as is with `@Dto(keyCase: KeyCase.field)`).
  String keyOf(FieldElement field, {required bool snake}) {
    String? name = annotations
        .first(field, 'Name')
        ?.getField('key')
        ?.toStringValue();
    if (name != null) return name;
    return snake ? toSnakeCase(field.displayName) : field.displayName;
  }

  /// Read [element]. Problems go to [DtoClass.errors].
  DtoClass read(ClassElement element) {
    DtoClass dto = DtoClass(element);
    DartObject? options = annotations.first(element, 'Dto');
    dto.source = options?.getField('source')?.variable?.displayName ?? 'auto';
    dto.strict = options?.getField('strict')?.toBoolValue() ?? false;
    bool snake =
        (options?.getField('keyCase')?.variable?.displayName ?? 'snake') ==
        'snake';
    Map<DartObject?, DartObject?>? messages = options
        ?.getField('messages')
        ?.toMapValue();
    for (MapEntry<DartObject?, DartObject?> entry
        in messages?.entries ?? const <MapEntry<DartObject?, DartObject?>>[]) {
      String? key = entry.key?.toStringValue();
      String? value = entry.value?.toStringValue();
      if (key != null && value != null) dto.messages[key] = value;
    }

    if (element.typeParameters.isNotEmpty) {
      dto.errors.add('A @Dto class can not be generic.');
    }
    InterfaceType? parent = element.supertype;
    if (parent != null && !parent.isDartCoreObject) {
      dto.errors.add(
        'A @Dto class can not extend another class '
        '(${parent.getDisplayString()}).',
      );
    }
    ConstructorElement? constructor = element.unnamedConstructor;
    if (constructor == null) {
      dto.errors.add('A @Dto class needs an unnamed constructor.');
      return dto;
    }
    Map<String, FormalParameterElement> params =
        <String, FormalParameterElement>{};
    for (FormalParameterElement param in constructor.formalParameters) {
      params[param.displayName] = param;
    }

    Set<String> keys = <String>{};
    for (FieldElement field in element.fields) {
      if (field.isStatic || !field.isOriginDeclaration) continue;
      String where = '${element.displayName}.${field.displayName}';
      if (!field.isFinal) {
        dto.errors.add('The field $where must be final.');
        continue;
      }
      FormalParameterElement? param = params[field.displayName];
      if (param is! FieldFormalParameterElement) {
        dto.errors.add(
          'The field $where must be a `this.${field.displayName}` '
          'parameter of the unnamed constructor.',
        );
        continue;
      }
      DtoField? read = _field(field, param, snake, dto.errors);
      if (read == null) continue;
      if (!keys.add(read.key)) {
        dto.errors.add(
          'Two fields of ${element.displayName} use the key '
          '"${read.key}".',
        );
      }
      dto.fields.add(read);
    }
    for (FormalParameterElement param in constructor.formalParameters) {
      DtoField? field = _byName(dto.fields, param.displayName);
      if (field != null) {
        dto.parameters.add(field);
      } else if (param.isRequired) {
        dto.errors.add(
          'The constructor parameter ${param.displayName} of '
          '${element.displayName} is not a field.',
        );
      }
    }
    _validateMethod(dto);
    return dto;
  }

  DtoField? _byName(List<DtoField> fields, String name) {
    for (DtoField field in fields) {
      if (field.name == name) return field;
    }
    return null;
  }

  void _validateMethod(DtoClass dto) {
    MethodElement? method = dto.element.getMethod('validate');
    if (method == null || method.isStatic) return;
    List<FormalParameterElement> args = method.formalParameters;
    if (args.length != 1 ||
        args.first.type.element?.displayName != 'DtoErrors') {
      dto.errors.add(
        'The validate method of ${dto.name} must take one DtoErrors: '
        '`void validate(DtoErrors errors)`.',
      );
      return;
    }
    DartType result = method.returnType;
    dto.validate = method;
    dto.validateIsAsync =
        result.isDartAsyncFuture || result.isDartAsyncFutureOr;
    if (!dto.validateIsAsync && result is! VoidType) {
      dto.errors.add(
        'The validate method of ${dto.name} must return void or Future<void>.',
      );
    }
  }

  DtoField? _field(
    FieldElement field,
    FormalParameterElement param,
    bool snake,
    List<String> errors,
  ) {
    String where = '${field.enclosingElement.displayName}.${field.displayName}';
    DartType type = field.type;
    bool maybe = false;
    if (type is InterfaceType && type.element.displayName == 'Maybe') {
      maybe = true;
      type = type.typeArguments.first;
      String? code = param.defaultValueCode?.replaceAll(' ', '');
      if (code == null ||
          !code.startsWith('constMaybe') ||
          !code.endsWith('.missing()')) {
        errors.add(
          'The Maybe field $where needs the default `const Maybe.missing()`.',
        );
      }
    }
    DtoType? dtoType = typeOf(type, where, errors);
    if (dtoType == null) return null;
    DtoField result = DtoField(
      element: field,
      name: field.displayName,
      key: keyOf(field, snake: snake),
      type: dtoType,
      maybe: maybe,
      defaultCode: maybe ? null : param.defaultValueCode,
      positional: param.isPositional,
    );
    _rules(result, where, errors);
    return result;
  }

  /// The [DtoType] of [type], or null (with an error) when it is not
  /// supported.
  DtoType? typeOf(DartType type, String where, List<String> errors) {
    if (type is DynamicType) return DtoType(DtoKind.any, type);
    if (type is! InterfaceType) {
      errors.add(
        'The type ${type.getDisplayString()} of $where is not '
        'supported.',
      );
      return null;
    }
    InterfaceElement element = type.element;
    String name = element.displayName;
    if (type.isDartCoreString) return DtoType(DtoKind.string, type);
    if (type.isDartCoreInt) return DtoType(DtoKind.integer, type);
    if (type.isDartCoreDouble) return DtoType(DtoKind.decimal, type);
    if (type.isDartCoreNum) return DtoType(DtoKind.number, type);
    if (type.isDartCoreBool) return DtoType(DtoKind.boolean, type);
    if (type.isDartCoreObject) return DtoType(DtoKind.any, type);
    if (element.library.isDartCore && name == 'DateTime') {
      return DtoType(DtoKind.date, type);
    }
    if (element is EnumElement) {
      return DtoType(
        DtoKind.enumName,
        type,
        enumNames: <String>[
          for (FieldElement value in element.constants) value.displayName,
        ],
      );
    }
    if (type.isDartCoreList) {
      DtoType? item = typeOf(type.typeArguments.first, '$where (item)', errors);
      return item == null ? null : DtoType(DtoKind.list, type, item: item);
    }
    if (type.isDartCoreMap) {
      if (!type.typeArguments.first.isDartCoreString) {
        errors.add('The map keys of $where must be String.');
        return null;
      }
      DartType value = type.typeArguments.last;
      if (value is DynamicType ||
          (value.isDartCoreObject &&
              value.nullabilitySuffix == NullabilitySuffix.question)) {
        return DtoType(DtoKind.anyMap, type);
      }
      DtoType? item = typeOf(value, '$where (value)', errors);
      return item == null ? null : DtoType(DtoKind.map, type, item: item);
    }
    if (isDto(element)) return DtoType(DtoKind.dto, type);
    if (_implements(type, 'FileInput')) return DtoType(DtoKind.file, type);
    errors.add(
      'The type ${type.getDisplayString()} of $where is not supported. '
      'Use a basic type, an enum, DateTime, RequestFile, a @Dto class, '
      'or a List or Map of them.',
    );
    return null;
  }

  bool _implements(InterfaceType type, String name) {
    if (type.element.displayName == name) return true;
    for (InterfaceType parent in type.allSupertypes) {
      if (parent.element.displayName == name) return true;
    }
    return false;
  }

  /// The `Rule<T>` supertype of [type], or null.
  InterfaceType? ruleType(DartType? type) {
    if (type is! InterfaceType) return null;
    for (InterfaceType parent in type.allSupertypes) {
      if (parent.element.displayName == 'Rule' &&
          parent.typeArguments.length == 1) {
        return parent;
      }
    }
    return null;
  }

  void _rules(DtoField field, String where, List<String> errors) {
    bool lower = false;
    bool upper = false;
    for (ElementAnnotation annotation in field.element.metadata.annotations) {
      DartObject? value = annotation.computeConstantValue();
      DartType? type = value?.type;
      if (value == null || type is! InterfaceType) continue;
      String name = type.element.displayName;
      String source = _source(annotation);
      InterfaceType? rule = ruleType(type);
      if (rule != null) {
        _custom(
          field,
          DtoRule(name, value, source, custom: true),
          rule,
          type,
          where,
          errors,
        );
        continue;
      }
      switch (name) {
        case 'Trim':
          field.trim = true;
        case 'Lowercase':
          lower = true;
          field.textCase = 1;
        case 'Uppercase':
          upper = true;
          field.textCase = 2;
        case 'AllowEmpty':
          field.allowEmpty = true;
      }
      if (textChanges.contains(name)) {
        _fits(field, name, where, errors, <DtoKind>{DtoKind.string});
        continue;
      }
      if (!builtIn.contains(name)) continue;
      DtoRule item = DtoRule(name, value, source);
      _builtIn(field, item, where, errors);
      field.rules.add(item);
    }
    if (lower && upper) {
      errors.add('$where can not have both @Lowercase and @Uppercase.');
    }
  }

  /// The annotation as a const expression: `@Slug()` => `const Slug()`.
  String _source(ElementAnnotation annotation) {
    String text = annotation.toSource().substring(1);
    return text.contains('(') ? 'const $text' : text;
  }

  /// The value type a rule checks: the list item for value rules on a
  /// list, else the field type.
  DtoType _target(DtoField field, DtoRule rule) {
    DtoType type = field.type;
    if (type.kind == DtoKind.list && !listRules.contains(rule.name)) {
      rule.onItems = true;
      return type.item!;
    }
    return type;
  }

  bool _fits(
    DtoField field,
    String name,
    String where,
    List<String> errors,
    Set<DtoKind> kinds,
  ) {
    DtoType type = field.type;
    if (type.kind == DtoKind.list) type = type.item!;
    if (kinds.contains(type.kind)) return true;
    errors.add('@$name does not fit the type ${field.fieldCode} of $where.');
    return false;
  }

  void _builtIn(
    DtoField field,
    DtoRule rule,
    String where,
    List<String> errors,
  ) {
    String name = rule.name;
    if (listRules.contains(name)) {
      if (field.type.kind != DtoKind.list) {
        errors.add(
          '@$name does not fit the type ${field.fieldCode} of '
          '$where. It is for lists.',
        );
        return;
      }
      if (name == 'UniqueItems' && !field.type.item!.isScalar) {
        errors.add(
          '@UniqueItems does not work on ${field.fieldCode} '
          '($where). Use it on a list of text, numbers, enums or dates.',
        );
      }
      return;
    }
    DtoType target = _target(field, rule);
    if (textRules.contains(name)) {
      if (!_fits(field, name, where, errors, <DtoKind>{DtoKind.string})) {
        return;
      }
      if (name == 'Length' &&
          rule.intField('min') == null &&
          rule.intField('max') == null) {
        errors.add('@Length on $where needs min:, max: or both.');
      }
      if (name == 'Regex') {
        try {
          RegExp(rule.stringField('pattern') ?? '');
        } on FormatException catch (error) {
          errors.add(
            'The @Regex on $where is not a valid regex: '
            '${error.message}',
          );
        }
      }
      return;
    }
    if (numberRules.contains(name)) {
      if (!_fits(field, name, where, errors, <DtoKind>{
        DtoKind.integer,
        DtoKind.decimal,
        DtoKind.number,
      })) {
        return;
      }
      if (target.kind == DtoKind.integer) {
        for (String key in <String>['value', 'min', 'max']) {
          DartObject? number = rule.value.getField(key);
          if (number != null &&
              number.toIntValue() == null &&
              number.toDoubleValue() != null) {
            errors.add(
              '@$name on $where uses a fraction, '
              'but the field is an int.',
            );
          }
        }
      }
      return;
    }
    if (valueRules.contains(name)) {
      _fits(field, name, where, errors, <DtoKind>{
        DtoKind.string,
        DtoKind.integer,
        DtoKind.decimal,
        DtoKind.number,
      });
      bool text = target.kind == DtoKind.string;
      for (DartObject item
          in rule.value.getField('values')?.toListValue() ??
              const <DartObject>[]) {
        bool isText = item.toStringValue() != null;
        if (isText != text) {
          errors.add(
            'The values of @$name on $where do not fit the type '
            '${target.code}.',
          );
          break;
        }
      }
      return;
    }
    if (dateRules.contains(name)) {
      if (!_fits(field, name, where, errors, <DtoKind>{DtoKind.date})) return;
      String date = rule.stringField('date') ?? '';
      if (date != 'now' && parseDate(date) == null) {
        errors.add(
          '@$name on $where needs an ISO 8601 date or \'now\', '
          'not "$date".',
        );
      }
      return;
    }
    if (fileRules.contains(name)) {
      if (!_fits(field, name, where, errors, <DtoKind>{DtoKind.file})) return;
      if (name == 'MaxSize' && sizeOf(rule.stringField('size') ?? '') == null) {
        errors.add(
          '@MaxSize on $where needs a size like \'2MB\' '
          '(units B, KB, MB, GB), not "${rule.stringField('size')}".',
        );
      }
    }
  }

  void _custom(
    DtoField field,
    DtoRule rule,
    InterfaceType ruleSuper,
    InterfaceType type,
    String where,
    List<String> errors,
  ) {
    rule.isAsync = _implements(type, 'AsyncRule');
    DartType checks = ruleSuper.typeArguments.first;
    TypeSystemLike system = TypeSystemLike(field.element.library);
    DtoType value = field.type;
    if (value.kind == DtoKind.list && system.fits(value.item!.type, checks)) {
      rule.onItems = true;
    } else if (!system.fits(value.type, checks)) {
      errors.add(
        '@${rule.name} checks ${checks.getDisplayString()}, it does '
        'not fit the type ${field.fieldCode} of $where.',
      );
      return;
    }
    field.rules.add(rule);
  }

  /// The bytes of a size text like `2MB`, or null.
  static int? sizeOf(String text) {
    RegExpMatch? match = RegExp(
      r'^\s*(\d+(?:\.\d+)?)\s*(B|KB|MB|GB)\s*$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    double number = double.parse(match[1]!);
    int unit = switch (match[2]!.toUpperCase()) {
      'KB' => 1024,
      'MB' => 1024 * 1024,
      'GB' => 1024 * 1024 * 1024,
      _ => 1,
    };
    return (number * unit).round();
  }

  /// An ISO 8601 date as UTC, or null. Same rules as the runtime.
  static DateTime? parseDate(String text) {
    RegExpMatch? match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})([T ]\d{2}:\d{2}(:\d{2}(\.\d{1,9})?)?(Z|[+-]\d{2}(:?\d{2})?)?)?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    int year = int.parse(match[1]!);
    int month = int.parse(match[2]!);
    int day = int.parse(match[3]!);
    DateTime check = DateTime.utc(year, month, day);
    if (check.month != month || check.day != day) return null;
    if (match[4] == null) return check;
    String value = match[7] == null ? '${text}Z' : text;
    return DateTime.tryParse(value.replaceFirst(' ', 'T'))?.toUtc();
  }

  /// Stop the build with all problems of [dto].
  void check(DtoClass dto) {
    if (dto.errors.isEmpty) return;
    StringBuffer text = StringBuffer(
      'The @Dto class ${dto.name} has problems:',
    );
    for (String error in dto.errors) {
      text.write('\n- $error');
    }
    throw InvalidGenerationSourceError(text.toString(), element: dto.element);
  }
}

/// `isAssignableTo` of the library type system.
class TypeSystemLike {
  TypeSystemLike(this.library);

  final LibraryElement library;

  bool fits(DartType value, DartType target) {
    return library.typeSystem.isAssignableTo(
      library.typeSystem.promoteToNonNull(value),
      target,
    );
  }
}
