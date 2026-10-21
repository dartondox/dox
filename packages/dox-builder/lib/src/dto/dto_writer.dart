import 'package:analyzer/dart/constant/value.dart';

import '../openapi/dart_literal.dart';
import 'dto_model.dart';

/// Facts about a DTO that depend on its nested DTOs too.
class DtoFlags {
  const DtoFlags({
    required this.checks,
    required this.checksAsync,
    required this.async,
  });

  /// a `validate()` method here or in a nested DTO
  final bool checks;

  /// a `validate()` that returns a Future, here or nested
  final bool checksAsync;

  /// an async rule (like `@Unique`), here or nested
  final bool async;
}

/// Gives the [DtoFlags] of a nested DTO class.
abstract class DtoFlagsSource {
  DtoFlags flagsOf(DtoType type);
}

/// Writes the generated code of one DTO: a `const $<Name>Dto`.
///
/// The code is plain Dart: one block of `if`s per field, no maps of
/// closures, no reflection. Regexes and dates are made once.
class DtoWriter {
  DtoWriter(
    this.dto,
    this.flags,
    this.jsonSchema, {
    this.literal = const DartLiteral(),
  });

  final DtoClass dto;
  final DtoFlagsSource flags;

  /// The JSON Schema of the DTO (with `$defs`), built at build time.
  final Map<String, dynamic> jsonSchema;
  final DartLiteral literal;

  final List<String> _statics = <String>[];
  int _regexes = 0;
  int _dates = 0;

  String get _class => '_\$${dto.name}Dto';

  String _ref(DtoType type) {
    return '\$${type.name}Dto';
  }

  /// The whole generated code of [dto].
  String write(DtoFlags own) {
    DtoFlags flags = own;
    String name = dto.name;
    String convert = _convert();
    String cross = flags.checks ? _crossCheck(flags) : '';
    String async = flags.async ? _checkAsync() : '';
    StringBuffer out = StringBuffer()
      ..writeln('/// The checks, the converter and the JSON Schema of [$name].')
      ..writeln('const DtoSchema<$name> \$${name}Dto = $_class();')
      ..writeln()
      ..writeln('class $_class extends DtoSchema<$name> {')
      ..writeln('const $_class();')
      ..writeln()
      ..writeln(
        'static const Map<String, String> _m = ${literal.stringMap(dto.messages)};',
      )
      ..writeln();
    if (dto.strict) {
      List<String> keys = <String>[
        for (DtoField field in dto.fields) _keyLiteral(field),
      ];
      out.writeln(
        'static const Set<String> _keys = <String>{${keys.join(', ')}};',
      );
    }
    for (String line in _statics) {
      out.writeln(line);
    }
    out
      ..writeln()
      ..writeln('@override')
      ..writeln('Type get type => $name;')
      ..writeln()
      ..writeln('@override')
      ..writeln("String get name => '$name';")
      ..writeln();
    if (dto.source != 'auto') {
      out
        ..writeln('@override')
        ..writeln('Source get source => Source.${dto.source};')
        ..writeln();
    }
    if (flags.checks) {
      out
        ..writeln('@override')
        ..writeln('bool get hasChecks => true;')
        ..writeln();
    }
    if (flags.async || flags.checksAsync) {
      out
        ..writeln('@override')
        ..writeln('bool get isAsync => true;')
        ..writeln();
    }
    out
      ..writeln(convert)
      ..writeln(cross)
      ..writeln(async)
      ..writeln(_fromMap())
      ..writeln(_toMap())
      ..writeln(_toJsonSchema())
      ..writeln('}');
    return out.toString();
  }

  String _keyLiteral(DtoField field) {
    return literal.string(field.key);
  }

  // ---------------------------------------------------------------------------
  // Steps 1 and 2
  // ---------------------------------------------------------------------------

  String _convert() {
    StringBuffer out = StringBuffer()
      ..writeln('@override')
      ..writeln(
        '${dto.name}? convert(Object? input, DtoState s, List<Object> p) {',
      )
      ..writeln('if (input is! Map) {')
      ..writeln('s.notObject(input, p, _m);')
      ..writeln('return null;')
      ..writeln('}')
      ..writeln('int e = s.issues.length;');
    if (dto.strict) {
      out
        ..writeln('for (Object? k in input.keys) {')
        ..writeln('if (!_keys.contains(k)) {')
        ..writeln(
          "s.fail(p, '\$k', IssueCodes.unrecognizedKeys, DefaultMessages.notAllowed, input[k], messages: _m);",
        )
        ..writeln('}')
        ..writeln('}');
    }
    for (int i = 0; i < dto.fields.length; i++) {
      DtoField field = dto.fields[i];
      String c = 'c$i';
      String key = _keyLiteral(field);
      out
        ..writeln('// ${field.name}: ${field.fieldCode}')
        ..writeln('Object? $c;');
      _conv(out, field, field.type, 's.read(input, $key)', 'p', key, c, 0);
      if (field.maybe) {
        if (!field.type.nullable) {
          out.writeln('if ($c == null) s.required(p, $key, _m);');
        }
      } else if (field.required) {
        out.writeln(
          'if ($c == null || $c is Undefined) s.required(p, $key, _m);',
        );
      } else if (!field.type.nullable) {
        out.writeln('if ($c == null) s.required(p, $key, _m);');
      }
    }
    out.writeln('if (s.issues.length != e) return null;');
    StringBuffer rules = StringBuffer();
    for (int i = 0; i < dto.fields.length; i++) {
      _fieldRules(rules, dto.fields[i], 'c$i');
    }
    // the rules of this DTO run when all its fields have the right type
    if (rules.isNotEmpty) {
      out
        ..write(rules)
        ..writeln('if (s.issues.length != e) return null;');
    }
    out.writeln('return ${dto.name}(${_arguments()});');
    out.writeln('}');
    return out.toString();
  }

  String _arguments() {
    List<String> args = <String>[];
    for (DtoField field in dto.parameters) {
      int i = dto.fields.indexOf(field);
      String value = _value(field, 'c$i');
      args.add(field.positional ? value : '${field.name}: $value');
    }
    return args.join(', ');
  }

  /// The constructor argument of [field] from its converted value [c].
  String _value(DtoField field, String c) {
    String type = field.type.code;
    if (field.maybe) {
      return '$c is Undefined ? const Maybe<$type>.missing() : Maybe<$type>($c as $type)';
    }
    String cast = field.type.kind == DtoKind.any ? c : '$c as $type';
    if (field.hasDefault) {
      return '$c is Undefined ? ${field.defaultCode} : $cast';
    }
    if (field.type.nullable) {
      return '$c is Undefined ? null : $cast';
    }
    return cast;
  }

  /// Statements that set [target] from [raw]: the typed value,
  /// `undefined`, `null` or `invalid`.
  void _conv(
    StringBuffer out,
    DtoField field,
    DtoType type,
    String raw,
    String path,
    String key,
    String target,
    int depth,
  ) {
    String args = '$raw, $path, $key, _m';
    switch (type.kind) {
      case DtoKind.string:
        List<String> options = <String>[
          if (field.trim) 'trim: true',
          if (field.textCase != 0) 'textCase: ${field.textCase}',
          if (field.allowEmpty) 'allowEmpty: true',
        ];
        String extra = options.isEmpty ? '' : ', ${options.join(', ')}';
        out.writeln('$target = s.string($args$extra);');
      case DtoKind.integer:
        out.writeln('$target = s.integer($args);');
      case DtoKind.decimal:
        out.writeln('$target = s.decimal($args);');
      case DtoKind.number:
        out.writeln('$target = s.number($args);');
      case DtoKind.boolean:
        out.writeln('$target = s.boolean($args);');
      case DtoKind.date:
        out.writeln('$target = s.date($args);');
      case DtoKind.file:
        out.writeln('$target = s.file($args);');
      case DtoKind.any:
        out.writeln('$target = $raw;');
      case DtoKind.anyMap:
        out.writeln('$target = s.object($args);');
      case DtoKind.enumName:
        String names = literal.strings(type.enumNames);
        out
          ..writeln('$target = s.enumName($args, const $names);')
          ..writeln('if ($target is String) {')
          ..writeln('$target = switch ($target) {');
        String enumType = type.nonNullCode;
        List<String> values = type.enumNames;
        for (int i = 0; i < values.length; i++) {
          String match = i == values.length - 1
              ? '_'
              : literal.string(values[i]);
          out.writeln('$match => $enumType.${values[i]},');
        }
        out
          ..writeln('};')
          ..writeln('}');
      case DtoKind.dto:
        out
          ..writeln('$target = s.object($args);')
          ..writeln('if ($target is Map) {')
          ..writeln(
            '$target = ${_ref(type)}.convert($target, s, <Object>[...$path, $key]) ?? invalid;',
          )
          ..writeln('}');
      case DtoKind.list:
        DtoType item = type.item!;
        String q = 'q$depth';
        String o = 'o$depth';
        String i = 'i$depth';
        String x = 'x$depth';
        out
          ..writeln('$target = s.list($args);')
          ..writeln('if ($target is List) {')
          ..writeln('List<Object> $q = <Object>[...$path, $key];')
          ..writeln('List<${item.code}> $o = <${item.code}>[];')
          ..writeln('for (int $i = 0; $i < $target.length; $i++) {')
          ..writeln('Object? $x;');
        _conv(out, field, item, '$target[$i]', q, i, x, depth + 1);
        _add(
          out,
          item,
          x,
          q,
          i,
          '$o.add($x as ${item.code});',
          '$o.add(null);',
        );
        out
          ..writeln('}')
          ..writeln('$target = $o;')
          ..writeln('}');
      case DtoKind.map:
        DtoType item = type.item!;
        String q = 'q$depth';
        String o = 'o$depth';
        String k = 'k$depth';
        String x = 'x$depth';
        String entry = 'n$depth';
        out
          ..writeln('$target = s.object($args);')
          ..writeln('if ($target is Map) {')
          ..writeln('List<Object> $q = <Object>[...$path, $key];')
          ..writeln('Map<String, ${item.code}> $o = <String, ${item.code}>{};')
          ..writeln(
            'for (MapEntry<dynamic, dynamic> $entry in $target.entries) {',
          )
          ..writeln("String $k = '\${$entry.key}';")
          ..writeln('Object? $x;');
        _conv(out, field, item, '$entry.value', q, k, x, depth + 1);
        _add(
          out,
          item,
          x,
          q,
          k,
          '$o[$k] = $x as ${item.code};',
          '$o[$k] = null;',
        );
        out
          ..writeln('}')
          ..writeln('$target = $o;')
          ..writeln('}');
    }
  }

  /// Add a converted item [x] to its list or map.
  void _add(
    StringBuffer out,
    DtoType item,
    String x,
    String path,
    String key,
    String add,
    String addNull,
  ) {
    if (item.nullable) {
      out
        ..writeln('if ($x == null || $x is Undefined) {')
        ..writeln(addNull)
        ..writeln('} else if ($x is! Invalid) {')
        ..writeln(add)
        ..writeln('}');
      return;
    }
    out
      ..writeln('if ($x == null || $x is Undefined) {')
      ..writeln('s.required($path, $key, _m);')
      ..writeln('} else if ($x is! Invalid) {')
      ..writeln(add)
      ..writeln('}');
  }

  /// The rules of one field. They see the converted value [c].
  void _fieldRules(StringBuffer out, DtoField field, String c) {
    List<DtoRule> listRules = <DtoRule>[];
    List<DtoRule> valueRules = <DtoRule>[];
    for (DtoRule rule in field.rules) {
      if (rule.isAsync) continue;
      (rule.onItems ? valueRules : listRules).add(rule);
    }
    if (listRules.isEmpty && valueRules.isEmpty) return;
    String key = _keyLiteral(field);
    DtoType type = field.type;
    out.writeln('if ($c is ${type.nonNullCode}) {');
    if (type.kind == DtoKind.list) {
      DtoType item = type.item!;
      StringBuffer items = StringBuffer();
      if (valueRules.isNotEmpty) {
        items
          ..writeln('List<Object> q = <Object>[...p, $key];')
          ..writeln('for (int i = 0; i < $c.length; i++) {')
          ..writeln('${item.code} v = $c[i];');
        if (item.nullable) items.writeln('if (v != null) {');
        _chain(items, valueRules, item, 'v', 'q', 'i', '');
        if (item.nullable) items.writeln('}');
        items.writeln('}');
      }
      _chain(out, listRules, type, c, 'p', key, items.toString());
    } else {
      _chain(
        out,
        <DtoRule>[...listRules, ...valueRules],
        type,
        c,
        'p',
        key,
        '',
      );
    }
    out.writeln('}');
  }

  /// `if (!a) fail else if (!b) fail ... else tail`: the first rule that
  /// fails gives the error.
  void _chain(
    StringBuffer out,
    List<DtoRule> rules,
    DtoType type,
    String v,
    String path,
    String key,
    String tail,
  ) {
    if (rules.isEmpty) {
      out.write(tail);
      return;
    }
    for (int i = 0; i < rules.length; i++) {
      DtoRule rule = rules[i];
      _Check check = _check(rule, type, v, path, key);
      out
        ..writeln('${i == 0 ? '' : '} else '}if (!(${check.condition})) {')
        ..writeln(check.fail);
    }
    if (tail.isNotEmpty) {
      out
        ..writeln('} else {')
        ..write(tail);
    }
    out.writeln('}');
  }

  String _fail(
    DtoRule rule,
    String path,
    String key,
    String v,
    String code,
    String fallback, [
    Map<String, Object?> params = const <String, Object?>{},
  ]) {
    String message = rule.message == null
        ? ''
        : ', message: ${literal.string(rule.message!)}';
    String paramText = params.isEmpty
        ? ''
        : ', params: const ${_params(params)}';
    return 's.fail($path, $key, IssueCodes.$code, DefaultMessages.$fallback, $v$paramText$message, messages: _m);';
  }

  String _params(Map<String, Object?> params) {
    StringBuffer out = StringBuffer('<String, Object?>{');
    for (MapEntry<String, Object?> entry in params.entries) {
      Object? value = entry.value;
      String code = value is String ? literal.string(value) : '$value';
      out.write('${literal.string(entry.key)}: $code, ');
    }
    out.write('}');
    return out.toString();
  }

  List<Object?> _list(DtoRule rule, String field) {
    return <Object?>[
      for (DartObject item
          in rule.value.getField(field)?.toListValue() ?? const <DartObject>[])
        literal.fromConstant(item),
    ];
  }

  String _join(List<Object?> values) {
    List<String> items = <String>[for (Object? value in values) '$value'];
    if (items.length <= 1) return items.join();
    String last = items.removeLast();
    return '${items.join(', ')}, and $last';
  }

  String _setLiteral(List<Object?> values, DtoType type) {
    String itemType = type.kind == DtoKind.string ? 'String' : 'num';
    List<String> items = <String>[
      for (Object? value in values)
        value is String ? literal.string(value) : '$value',
    ];
    return 'const <$itemType>{${items.join(', ')}}';
  }

  DtoRule? _rule;
  String _path = 'p';
  String _key = '';
  String _v = '';

  /// The fail call of the current rule of [_check].
  String f(
    String code,
    String fallback, [
    Map<String, Object?> params = const <String, Object?>{},
  ]) {
    return _fail(_rule!, _path, _key, _v, code, fallback, params);
  }

  _Check _check(DtoRule rule, DtoType type, String v, String path, String key) {
    if (rule.custom) {
      return _Check(
        '${rule.source}.check($v, s.context($path, $key, $v))',
        's.failRule(${rule.source}, $path, $key, $v, _m);',
      );
    }
    _rule = rule;
    _path = path;
    _key = key;
    _v = v;
    switch (rule.name) {
      case 'Length':
        int? min = rule.intField('min');
        int? max = rule.intField('max');
        String len = '$v.runes.length';
        if (min != null && max != null && min == max) {
          return _Check(
            '$len == $min',
            f('length', 'length', <String, Object?>{'length': min}),
          );
        }
        if (min != null && max != null) {
          return _Check(
            '$len >= $min && $len <= $max',
            f('lengthBetween', 'lengthBetween', <String, Object?>{
              'min': min,
              'max': max,
            }),
          );
        }
        if (min != null) {
          return _Check(
            '$len >= $min',
            f('minLength', 'minLength', <String, Object?>{'min': min}),
          );
        }
        return _Check(
          '$len <= $max',
          f('maxLength', 'maxLength', <String, Object?>{'max': max}),
        );
      case 'MinLength':
        int n = rule.intField('value')!;
        return _Check(
          '$v.runes.length >= $n',
          f('minLength', 'minLength', <String, Object?>{'min': n}),
        );
      case 'MaxLength':
        int n = rule.intField('value')!;
        return _Check(
          '$v.runes.length <= $n',
          f('maxLength', 'maxLength', <String, Object?>{'max': n}),
        );
      case 'Email':
        return _Check('Patterns.email.hasMatch($v)', f('email', 'email'));
      case 'Url':
        return _Check('DtoChecks.url($v)', f('url', 'url'));
      case 'Uuid':
        return _Check('Patterns.uuid.hasMatch($v)', f('uuid', 'uuid'));
      case 'Ip':
        return _Check('DtoChecks.ip($v)', f('ip', 'ip'));
      case 'Regex':
        String name = '_r${_regexes++}';
        String pattern = '^(?:${rule.stringField('pattern')})\$';
        _statics.add(
          'static final RegExp $name = RegExp(${literal.string(pattern)});',
        );
        return _Check('$name.hasMatch($v)', f('regex', 'regex'));
      case 'StartsWith':
        String prefix = rule.stringField('prefix')!;
        return _Check(
          '$v.startsWith(${literal.string(prefix)})',
          f('startWith', 'startWith', <String, Object?>{'prefix': prefix}),
        );
      case 'EndsWith':
        String suffix = rule.stringField('suffix')!;
        return _Check(
          '$v.endsWith(${literal.string(suffix)})',
          f('endWith', 'endWith', <String, Object?>{'suffix': suffix}),
        );
      case 'Alpha':
        return _Check('Patterns.alpha.hasMatch($v)', f('alpha', 'alpha'));
      case 'AlphaNumeric':
        return _Check(
          'Patterns.alphaNumeric.hasMatch($v)',
          f('alphaNumeric', 'alphaNumeric'),
        );
      case 'AlphaDash':
        return _Check(
          'Patterns.alphaDash.hasMatch($v)',
          f('alphaDash', 'alphaDash'),
        );
      case 'In':
        List<Object?> values = _list(rule, 'values');
        return _Check(
          '${_setLiteral(values, type)}.contains($v)',
          f('inList', 'inList', <String, Object?>{'values': _join(values)}),
        );
      case 'NotIn':
        List<Object?> values = _list(rule, 'values');
        return _Check(
          '!${_setLiteral(values, type)}.contains($v)',
          f('notIn', 'notIn'),
        );
      case 'Min':
        num n = rule.numField('value')!;
        return _Check('$v >= $n', f('min', 'min', <String, Object?>{'min': n}));
      case 'Max':
        num n = rule.numField('value')!;
        return _Check('$v <= $n', f('max', 'max', <String, Object?>{'max': n}));
      case 'Range':
        num min = rule.numField('min')!;
        num max = rule.numField('max')!;
        return _Check(
          '$v >= $min && $v <= $max',
          f('between', 'between', <String, Object?>{'min': min, 'max': max}),
        );
      case 'Positive':
        return _Check(
          '$v > 0',
          f('greaterThan', 'greaterThan', <String, Object?>{'min': 0}),
        );
      case 'GreaterThan':
        num n = rule.numField('value')!;
        return _Check(
          '$v > $n',
          f('greaterThan', 'greaterThan', <String, Object?>{'min': n}),
        );
      case 'LessThan':
        num n = rule.numField('value')!;
        return _Check(
          '$v < $n',
          f('lessThan', 'lessThan', <String, Object?>{'max': n}),
        );
      case 'MinItems':
        int n = rule.intField('value')!;
        return _Check(
          '$v.length >= $n',
          f('minItems', 'minItems', <String, Object?>{'min': n}),
        );
      case 'MaxItems':
        int n = rule.intField('value')!;
        return _Check(
          '$v.length <= $n',
          f('maxItems', 'maxItems', <String, Object?>{'max': n}),
        );
      case 'UniqueItems':
        return _Check(
          '!DtoChecks.hasDuplicates($v)',
          f('uniqueItems', 'uniqueItems'),
        );
      case 'After':
      case 'Before':
        String date = rule.stringField('date')!;
        String other = 's.now';
        if (date != 'now') {
          other = '_d${_dates++}';
          int micros = DtoReader.parseDate(date)!.microsecondsSinceEpoch;
          _statics.add(
            'static final DateTime $other = DateTime.fromMicrosecondsSinceEpoch($micros, isUtc: true);',
          );
        }
        String code = rule.name == 'After' ? 'after' : 'before';
        String method = rule.name == 'After' ? 'isAfter' : 'isBefore';
        return _Check(
          '$v.$method($other)',
          f(code, code, <String, Object?>{'date': date}),
        );
      case 'MaxSize':
        String size = rule.stringField('size')!;
        int bytes = DtoReader.sizeOf(size)!;
        return _Check(
          '$v.length <= $bytes',
          f('maxSize', 'maxSize', <String, Object?>{'max': size}),
        );
      case 'Mimes':
        List<String> types = <String>[
          for (Object? type in _list(rule, 'types')) '$type'.toLowerCase(),
        ];
        return _Check(
          'FileTypes.matches($v, const ${literal.strings(types)})',
          f('mimes', 'mimes', <String, Object?>{'types': types.join(', ')}),
        );
      case 'Image':
        return _Check(
          'FileTypes.matches($v, SchemaConstants.imageExtensions)',
          f('image', 'image'),
        );
    }
    throw StateError('Unknown rule ${rule.name}');
  }

  // ---------------------------------------------------------------------------
  // Step 3: validate()
  // ---------------------------------------------------------------------------

  String _crossCheck(DtoFlags flags) {
    bool async = flags.checksAsync;
    StringBuffer out = StringBuffer()
      ..writeln('@override')
      ..writeln(
        async
            ? 'Future<void> crossCheck(${dto.name} o, DtoState s, List<Object> p) async {'
            : 'void crossCheck(${dto.name} o, DtoState s, List<Object> p) {',
      );
    String wait = async ? 'await ' : '';
    for (DtoField field in dto.fields) {
      _nested(out, field, 'crossCheck', wait);
    }
    if (dto.validate != null) {
      out.writeln(
        '${dto.validateIsAsync ? wait : ''}o.validate(DtoErrors(s, p));',
      );
    }
    out.writeln('}');
    return out.toString();
  }

  /// Calls [method] (`crossCheck` or `checkAsync`) of each nested DTO
  /// value of [field] that needs it.
  void _nested(StringBuffer out, DtoField field, String method, String wait) {
    DtoType type = field.type;
    DtoType? dtoType = type.kind == DtoKind.dto
        ? type
        : (type.kind == DtoKind.list || type.kind == DtoKind.map) &&
              type.item!.kind == DtoKind.dto
        ? type.item
        : null;
    if (dtoType == null) return;
    DtoFlags nested = flags.flagsOf(dtoType);
    if (!(method == 'crossCheck' ? nested.checks : nested.async)) return;
    String key = _keyLiteral(field);
    String ref = _ref(dtoType);
    out.writeln('{');
    out.writeln('${field.fieldCode} f = o.${field.name};');
    String value = 'f';
    if (field.maybe) {
      out.writeln('if (f.isPresent) {');
      out.writeln('${type.code} g = f.value;');
      value = 'g';
    }
    if (type.nullable) out.writeln('if ($value != null) {');
    if (type.kind == DtoKind.dto) {
      out.writeln('$wait$ref.$method($value, s, <Object>[...p, $key]);');
    } else if (type.kind == DtoKind.list) {
      out
        ..writeln('for (int i = 0; i < $value.length; i++) {')
        ..writeln('${type.item!.code} x = $value[i];');
      if (type.item!.nullable) out.writeln('if (x != null)');
      out
        ..writeln('$wait$ref.$method(x, s, <Object>[...p, $key, i]);')
        ..writeln('}');
    } else {
      out
        ..writeln(
          'for (MapEntry<String, ${type.item!.code}> x in $value.entries) {',
        )
        ..writeln('${type.item!.code} y = x.value;');
      if (type.item!.nullable) out.writeln('if (y != null)');
      out
        ..writeln('$wait$ref.$method(y, s, <Object>[...p, $key, x.key]);')
        ..writeln('}');
    }
    if (type.nullable) out.writeln('}');
    if (field.maybe) out.writeln('}');
    out.writeln('}');
  }

  // ---------------------------------------------------------------------------
  // Step 4: async rules
  // ---------------------------------------------------------------------------

  String _checkAsync() {
    StringBuffer out = StringBuffer()
      ..writeln('@override')
      ..writeln(
        'Future<void> checkAsync(${dto.name} o, DtoState s, List<Object> p) async {',
      );
    for (DtoField field in dto.fields) {
      List<DtoRule> rules = <DtoRule>[
        for (DtoRule rule in field.rules)
          if (rule.isAsync) rule,
      ];
      if (rules.isNotEmpty) {
        String key = _keyLiteral(field);
        DtoType type = field.type;
        out
          ..writeln('{')
          ..writeln('${field.fieldCode} f = o.${field.name};');
        String value = 'f';
        if (field.maybe) {
          out
            ..writeln('if (f.isPresent) {')
            ..writeln('${type.code} g = f.value;');
          value = 'g';
        }
        if (type.nullable) out.writeln('if ($value != null) {');
        for (DtoRule rule in rules) {
          String method = rule.onItems ? 'asyncItems' : 'asyncRule';
          out.writeln('await s.$method(${rule.source}, $value, p, $key, _m);');
        }
        if (type.nullable) out.writeln('}');
        if (field.maybe) out.writeln('}');
        out.writeln('}');
      }
      _nested(out, field, 'checkAsync', 'await ');
    }
    out.writeln('}');
    return out.toString();
  }

  // ---------------------------------------------------------------------------
  // fromMap, toMap, toJsonSchema
  // ---------------------------------------------------------------------------

  String _fromMap() {
    List<String> args = <String>[];
    for (DtoField field in dto.parameters) {
      String key = _keyLiteral(field);
      String read = 'm[$key]';
      String value = _from(field.type, read, 0);
      if (field.maybe) {
        String type = field.type.code;
        value =
            'm.containsKey($key) ? Maybe<$type>($value) : const Maybe<$type>.missing()';
      } else if (field.hasDefault) {
        value = 'm.containsKey($key) ? $value : ${field.defaultCode}';
      }
      args.add(field.positional ? value : '${field.name}: $value');
    }
    return '@override\n'
        '${dto.name} fromMap(Map<String, dynamic> m) {\n'
        'return ${dto.name}(${args.join(', ')});\n'
        '}\n';
  }

  /// [raw] (JSON-like) as [type], with no checks.
  String _from(DtoType type, String raw, int depth) {
    String code = switch (type.kind) {
      DtoKind.string => '$raw as String',
      DtoKind.integer => '($raw as num).toInt()',
      DtoKind.decimal => '($raw as num).toDouble()',
      DtoKind.number => '$raw as num',
      DtoKind.boolean => '$raw as bool',
      DtoKind.date => 'DateTime.parse($raw as String).toUtc()',
      DtoKind.enumName => '${type.nonNullCode}.values.byName($raw as String)',
      DtoKind.file => '$raw as ${type.nonNullCode}',
      DtoKind.any => raw,
      DtoKind.anyMap => '$raw as Map<String, dynamic>',
      DtoKind.dto => '${_ref(type)}.fromMap($raw as Map<String, dynamic>)',
      DtoKind.list =>
        '<${type.item!.code}>[for (Object? x$depth in $raw as List<dynamic>) ${_from(type.item!, 'x$depth', depth + 1)}]',
      DtoKind.map =>
        '<String, ${type.item!.code}>{for (MapEntry<dynamic, dynamic> x$depth in ($raw as Map<dynamic, dynamic>).entries) x$depth.key as String: ${_from(type.item!, 'x$depth.value', depth + 1)}}',
    };
    if (type.nullable && type.kind != DtoKind.any) {
      return '$raw == null ? null : ${_wrap(code)}';
    }
    return code;
  }

  String _wrap(String code) {
    return code.contains(' ') ? '($code)' : code;
  }

  String _toMap() {
    StringBuffer out = StringBuffer()
      ..writeln('@override')
      ..writeln('Map<String, dynamic> toMap(${dto.name} o) {');
    List<String> entries = <String>[];
    for (int i = 0; i < dto.fields.length; i++) {
      DtoField field = dto.fields[i];
      String key = _keyLiteral(field);
      String local = 'f$i';
      if (field.maybe) {
        String type = field.type.code;
        out.writeln('${field.fieldCode} $local = o.${field.name};');
        entries.add(
          'if ($local case Maybe<$type>(isPresent: true, value: $type g$i)) '
          '$key: ${_toValue(field.type, 'g$i', 0)}',
        );
      } else {
        out.writeln('${field.fieldCode} $local = o.${field.name};');
        entries.add('$key: ${_toValue(field.type, local, 0)}');
      }
    }
    out
      ..writeln('return <String, dynamic>{${entries.join(', ')}};')
      ..writeln('}');
    return out.toString();
  }

  /// [value] (of [type]) as a JSON-like value.
  String _toValue(DtoType type, String value, int depth) {
    String? code = switch (type.kind) {
      DtoKind.date => 'X.toIso8601String()',
      DtoKind.enumName => 'X.name',
      DtoKind.dto => '${_ref(type)}.toMap(X)',
      DtoKind.list =>
        _identity(type.item!)
            ? null
            : '<dynamic>[for (${type.item!.code} x$depth in X) ${_toValue(type.item!, 'x$depth', depth + 1)}]',
      DtoKind.map =>
        _identity(type.item!)
            ? null
            : '<String, dynamic>{for (MapEntry<String, ${type.item!.code}> x$depth in X.entries) x$depth.key: ${_toValue(type.item!, 'x$depth.value', depth + 1)}}',
      _ => null,
    };
    if (code == null) return value;
    String result = code.replaceAll('X', value);
    return type.nullable ? '$value == null ? null : $result' : result;
  }

  bool _identity(DtoType item) {
    return item.kind != DtoKind.date &&
        item.kind != DtoKind.enumName &&
        item.kind != DtoKind.dto &&
        ((item.kind != DtoKind.list && item.kind != DtoKind.map) ||
            _identity(item.item!));
  }

  String _toJsonSchema() {
    StringBuffer out = StringBuffer()
      ..writeln('@override')
      ..writeln('Map<String, dynamic> toJsonSchema() {');
    List<String> patches = <String>[];
    for (DtoField field in dto.fields) {
      for (DtoRule rule in field.rules) {
        if (!rule.custom) continue;
        String key = _keyLiteral(field);
        String path = rule.onItems
            ? "<String>['properties', $key, 'items']"
            : "<String>['properties', $key]";
        patches.add(
          'JsonSchemaTools.merge(j, $path, ${rule.source}.toJsonSchema());',
        );
      }
    }
    if (patches.isEmpty) {
      out.writeln('return ${literal.write(jsonSchema)};');
    } else {
      out.writeln('Map<String, dynamic> j = ${literal.write(jsonSchema)};');
      for (String patch in patches) {
        out.writeln(patch);
      }
      out.writeln('return j;');
    }
    out.writeln('}');
    return out.toString();
  }
}

class _Check {
  const _Check(this.condition, this.fail);

  final String condition;
  final String fail;
}
