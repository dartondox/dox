import 'dart:convert';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../openapi/dart_literal.dart';
import '../util.dart';
import 'dto_model.dart';

/// Facts about a DTO that depend on its nested DTOs too.
class DtoFlags {
  const DtoFlags({
    required this.checks,
    required this.checksAsync,
    required this.async,
    this.requiredWhen = true,
  });

  /// a `validate()` method here or in a nested DTO
  final bool checks;

  /// a `validate()` that returns a Future, here or nested
  final bool checksAsync;

  /// an async rule (like `@Unique`), here or nested
  final bool async;

  /// a `@RequiredIf` or `@RequiredWith` field, here or nested. `true` is
  /// the safe side: the check keeps the converted values.
  final bool requiredWhen;
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
    this.runtimeFlags = false,
    this.jsonWriter = false,
  }) : _serialize = false;

  /// The code of a plain `@Serialize()` class: only its JSON writer and
  /// its map, see [writeSerialize].
  DtoWriter.serialize(this.dto, {this.literal = const DartLiteral()})
    : flags = const _NoFlags(),
      jsonSchema = const <String, dynamic>{},
      runtimeFlags = false,
      jsonWriter = true,
      _serialize = true;

  /// true for [DtoWriter.serialize]
  final bool _serialize;

  static const DtoReader _reader = DtoReader();

  final DtoClass dto;
  final DtoFlagsSource flags;

  /// The JSON Schema of the DTO (with `$defs`), built at build time.
  final Map<String, dynamic> jsonSchema;
  final DartLiteral literal;

  /// `true` when the dox_validation of the app has the DTO flags
  /// (`DtoState.allErrors`). Then the code reads them at run time. An
  /// older dox_validation gets the old code, so it still compiles.
  final bool runtimeFlags;

  /// `true` when the dox_annotation of the app has `JsonObjectWriter`.
  /// Then the schema gets `writeObject()`, and dox_core writes the DTO
  /// in a response with no map. An older dox_annotation does not get it.
  final bool jsonWriter;

  /// A DTO with its own `toJson()` keeps it: dox_core calls that method.
  /// The method can also come from a class or a mixin above the DTO.
  bool get _writesJson => jsonWriter && !hasMethod(dto.element, 'toJson');

  /// The code of a plain `@Serialize()` class: a `SerializeWriter` for
  /// the JSON encoder, the function `$writeName` that writes the JSON,
  /// and the function `$NameToMap` that gives the same JSON as a map, for
  /// the encoder of the Dart SDK.
  String writeSerialize() {
    String name = dto.name;
    String writer = _writeFunction();
    StringBuffer out = StringBuffer()
      ..writeln('/// The JSON writer of [$name]. Dox gets it from')
      ..writeln('/// `lib/generated/container.g.dart`.')
      ..writeln('const SerializeWriter \$${name}Writer = $_class();')
      ..writeln()
      ..writeln('class $_class implements SerializeWriter {')
      ..writeln('const $_class();')
      ..writeln();
    for (String line in _statics) {
      out.writeln(line);
    }
    out
      ..writeln()
      ..writeln('@override')
      ..writeln('Type get type => $name;')
      ..writeln()
      ..writeln('@override')
      ..writeln(
        'void writeObject(Object object, JsonWriter writer) => '
        '\$write$name(object as $name, writer);',
      )
      ..writeln()
      ..writeln('@override')
      ..writeln(
        'Object? toJsonValue(Object object) => '
        '\$${name}ToMap(object as $name);',
      )
      ..writeln('}')
      ..writeln()
      ..writeln(writer)
      ..writeln(_toMap());
    return out.toString();
  }

  final List<String> _statics = <String>[];
  int _regexes = 0;
  int _dates = 0;
  final Set<String> _runNames = <String>{};

  /// Names that `convert()` declares or uses. A field local must not
  /// take one of them.
  static const Set<String> _emittedNames = <String>{
    r'$n',
    r'$v',
    'num',
    'int',
    'double',
    'bool',
    'String',
    'Object',
    'List',
    'Map',
    'MapEntry',
    'Set',
    'DateTime',
    'RegExp',
    'Undefined',
    'Invalid',
    'Maybe',
    'IssueCodes',
    'DefaultMessages',
    'Patterns',
    'JsonRun',
    'JsonWriter',
    'DtoState',
    'DtoErrors',
    'DtoChecks',
    'DtoSchema',
    'FileTypes',
    'ImageSize',
    'SchemaConstants',
    'JsonSchemaTools',
    'Type',
    'Source',
  };

  static const Set<String> _convertNames = <String>{
    'input',
    'state',
    'path',
    'issuesBefore',
    'undefined',
    'invalid',
    // the loop variables of the rules and of the strict check
    'k',
    'q',
    'i',
    'v',
    '_messages',
    '_attributes',
    '_keys',
  };

  /// Names that code from the user puts into the generated code: rules,
  /// defaults and types. A local with such a name would hide them.
  late final Set<String> _foreignNames = _readForeignNames();

  Set<String> _readForeignNames() {
    // text in quotes and a name after a dot are not looked up in the scope
    RegExp skip = RegExp(r"""'[^']*'|"[^"]*"|\.\s*[A-Za-z_$][A-Za-z0-9_$]*""");
    RegExp word = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*');
    Set<String> names = <String>{};
    void add(String? code) {
      if (code == null) return;
      for (RegExpMatch match in word.allMatches(code.replaceAll(skip, ' '))) {
        names.add(match[0]!);
      }
    }

    add(dto.name);
    for (DtoField field in dto.fields) {
      add(field.fieldCode);
      add(field.type.code);
      add(field.defaultCode);
      for (DtoRule rule in <DtoRule>[
        ...field.rules,
        ...field.exclude,
        ...field.requiredWhen,
      ]) {
        add(rule.source);
      }
    }
    return names;
  }

  String get _class =>
      _serialize ? '_\$${dto.name}Writer' : '_\$${dto.name}Dto';

  String _ref(DtoType type) {
    return '${type.prefix}\$${type.name}Dto';
  }

  /// The whole generated code of [dto].
  String write(DtoFlags own) {
    DtoFlags flags = own;
    String name = dto.name;
    String convert = _convert();
    // before the statics are written: it adds the runs of the JSON
    String writer = _writesJson ? _writeFunction() : '';
    String cross = flags.checks ? _crossCheck(flags) : '';
    String async = flags.async ? _checkAsync() : '';
    StringBuffer out = StringBuffer()
      ..writeln('/// The checks, the converter and the JSON Schema of [$name].')
      ..writeln('const DtoSchema<$name> \$${name}Dto = $_class();')
      ..writeln()
      ..writeln(
        'class $_class extends DtoSchema<$name> '
        '${_writesJson ? 'implements JsonObjectWriter ' : ''}{',
      )
      ..writeln('const $_class();')
      ..writeln()
      ..writeln(
        'static const Map<String, String> _messages = ${literal.stringMap(dto.messages)};',
      )
      ..writeln();
    if (dto.attributes.isNotEmpty) {
      out
        ..writeln(
          'static const Map<String, String> _attributes = ${literal.stringMap(dto.attributes)};',
        )
        ..writeln();
    }
    if (dto.strict) {
      // the key `@Confirmed` reads is not a field, but it is not unknown
      Set<String> keys = <String>{
        for (DtoField field in dto.fields) _keyLiteral(field),
        for (DtoField field in dto.fields)
          for (DtoRule rule in field.rules)
            if (rule.custom && rule.name == 'Confirmed')
              literal.string(
                rule.stringField('other') ?? '${field.key}_confirmation',
              ),
      };
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
    if (!flags.requiredWhen) {
      out
        ..writeln('@override')
        ..writeln('bool get usesRequiredWhen => false;')
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
      ..writeln(_writesJson ? _writeObject() : '')
      ..writeln(_toJsonSchema())
      ..writeln('}')
      ..writeln(writer);
    return out.toString();
  }

  String _keyLiteral(DtoField field) {
    return literal.string(field.key);
  }

  // ---------------------------------------------------------------------------
  // Steps 1 and 2
  // ---------------------------------------------------------------------------

  /// The names of the locals in `convert()`, one for each field. A field
  /// local has the name of its field, unless that name is taken.
  List<String> _locals = <String>[];

  String _convert() {
    Set<String> taken = <String>{
      ..._emittedNames,
      ..._convertNames,
      ..._foreignNames,
    };
    _locals = <String>[
      for (DtoField field in dto.fields) safeLocal(field.name, taken),
    ];
    StringBuffer out = StringBuffer()
      ..writeln('@override')
      ..writeln(
        '${dto.name}? convert(Object? input, DtoState state, List<Object> path) {',
      );
    // @Dto(attributes:): the names for {field} in this DTO
    if (dto.attributes.isNotEmpty) {
      out.writeln('state.attributes(path, _attributes);');
    }
    out
      ..writeln('if (input is! Map) {')
      ..writeln('state.notObject(input, path, _messages);')
      ..writeln('return null;')
      ..writeln('}')
      ..writeln('int issuesBefore = state.issues.length;');
    if (dto.strict) {
      out
        ..writeln('for (Object? k in input.keys) {')
        ..writeln('if (!_keys.contains(k)) {')
        ..writeln(
          "state.fail(path, '\$k', IssueCodes.unrecognizedKeys, DefaultMessages.notAllowed, input[k], messages: _messages);",
        )
        ..writeln('}')
        ..writeln('}');
    }
    StringBuffer requiredWhen = StringBuffer();
    for (int i = 0; i < dto.fields.length; i++) {
      DtoField field = dto.fields[i];
      String c = _locals[i];
      String key = _keyLiteral(field);
      out.writeln('// ${field.name}: ${field.fieldCode}');
      // @ExcludeIf / @ExcludeUnless: the field is not read, as if it was
      // not sent
      String excluded = <String>[
        for (DtoRule rule in field.exclude) '${rule.source}.appliesTo(input)',
      ].join(' || ');
      bool split = excluded.isNotEmpty;
      String skip = split ? safeLocal('${c}Excluded', taken) : '';
      if (split) {
        out
          ..writeln('Object? $c;')
          ..writeln('bool $skip = $excluded;')
          ..writeln('if ($skip) {')
          ..writeln('$c = undefined;')
          ..writeln('} else {');
      }
      String before = field.orDefault
          ? safeLocal('${c}IssuesBefore', taken)
          : '';
      if (field.orDefault) out.writeln('int $before = state.issues.length;');
      String read = dto.emptyStringsToNull
          ? dto.trim
                ? 'state.read(input, $key, emptyToNull: true, trim: true)'
                : 'state.read(input, $key, emptyToNull: true)'
          : 'state.read(input, $key)';
      _conv(out, field, field.type, read, 'path', key, c, 0, declare: !split);
      if (field.maybe) {
        if (!field.type.nullable) {
          // ValidationFlags.dtoMaybeRejectsEmpty: a key sent with ""
          String sent = runtimeFlags
              ? ' || state.sentEmpty($c, input, $key)'
              : '';
          out.writeln(
            'if ($c == null$sent) state.required(path, $key, _messages);',
          );
        }
      } else if (field.required) {
        if (runtimeFlags && field.type.kind == DtoKind.list) {
          // ValidationFlags.dtoRejectEmptyList: `[]`. A list that fails
          // `required` is bad, so its other rules do not run.
          out
            ..writeln(
              'if ($c == null || $c is Undefined || state.emptyList($c)) {',
            )
            ..writeln('state.required(path, $key, _messages);')
            ..writeln('$c = invalid;')
            ..writeln('}');
        } else {
          out.writeln(
            'if ($c == null || $c is Undefined) state.required(path, $key, _messages);',
          );
        }
      } else if (!field.type.nullable) {
        out.writeln('if ($c == null) state.required(path, $key, _messages);');
      }
      // @OrDefault: a type error (or null) gives the default
      if (field.orDefault) {
        out.writeln('if (state.dropIssuesAfter($before)) $c = undefined;');
      }
      if (split) out.writeln('}');
      // requiredWhen checks if the value is missing (blank text and an
      // empty list count as missing too). It runs after all fields are
      // converted, so it reads the converted value of a later field too.
      for (DtoRule rule in field.requiredWhen) {
        requiredWhen.writeln(
          '${split ? 'if (!$skip) ' : ''}state.requiredWhen(${rule.source}, $c, input, path, $key, _messages);',
        );
      }
    }
    // ValidationFlags.dtoAllErrors: the rules still run. Each rule checks
    // the type of its value first, so a bad field skips its rules.
    out
      ..write(requiredWhen)
      ..writeln(
        runtimeFlags
            ? 'if (state.issues.length != issuesBefore && !state.allErrors) return null;'
            : 'if (state.issues.length != issuesBefore) return null;',
      );
    StringBuffer rules = StringBuffer();
    for (int i = 0; i < dto.fields.length; i++) {
      DtoField field = dto.fields[i];
      StringBuffer one = StringBuffer();
      String c = _locals[i];
      _fieldRules(one, field, c);
      if (field.orDefault && one.isNotEmpty) {
        // @OrDefault: a failed rule gives the default too
        String before = safeLocal('${c}IssuesBeforeRules', taken);
        rules
          ..writeln('int $before = state.issues.length;')
          ..write(one)
          ..writeln('if (state.dropIssuesAfter($before)) $c = undefined;');
      } else {
        rules.write(one);
      }
    }
    // the rules of this DTO run when all its fields have the right type
    if (rules.isNotEmpty || runtimeFlags) {
      out
        ..write(rules)
        ..writeln('if (state.issues.length != issuesBefore) return null;');
    }
    out.writeln('return ${dto.name}(${_arguments()});');
    out.writeln('}');
    return out.toString();
  }

  String _arguments() {
    List<String> args = <String>[];
    for (DtoField field in dto.parameters) {
      int i = dto.fields.indexOf(field);
      String value = _value(field, _locals[i]);
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
    int depth, {
    required bool declare,
  }) {
    // the first statement can declare the variable
    String set = declare ? 'Object? $target = ' : '$target = ';
    String args = '$raw, $path, $key, _messages';
    // @Dto(coerce: true): JSON text becomes a number or a bool
    String coerce = dto.coerce ? ', coerce: true' : '';
    switch (type.kind) {
      case DtoKind.string:
        List<String> options = <String>[
          if (field.trim) 'trim: true',
          if (field.textCase != 0) 'textCase: ${field.textCase}',
          if (field.allowEmpty) 'allowEmpty: true',
        ];
        String extra = options.isEmpty ? '' : ', ${options.join(', ')}';
        out.writeln('${set}state.string($args$extra);');
      case DtoKind.integer:
        out.writeln('${set}state.integer($args$coerce);');
      case DtoKind.decimal:
        out.writeln('${set}state.decimal($args$coerce);');
      case DtoKind.number:
        out.writeln('${set}state.number($args$coerce);');
      case DtoKind.boolean:
        out.writeln('${set}state.boolean($args$coerce);');
      case DtoKind.date:
        out.writeln('${set}state.date($args);');
      case DtoKind.file:
        out.writeln('${set}state.file($args);');
      case DtoKind.any:
        out.writeln('$set$raw;');
      case DtoKind.anyMap:
        out.writeln('${set}state.object($args);');
      case DtoKind.enumName:
        String names = literal.strings(type.enumNames);
        out
          ..writeln('${set}state.enumName($args, const $names);')
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
          ..writeln('${set}state.object($args);')
          ..writeln('if ($target is Map) {')
          ..writeln(
            '$target = ${_ref(type)}.convert($target, state, <Object>[...$path, $key]) ?? invalid;',
          )
          ..writeln('}');
      case DtoKind.list:
        DtoType item = type.item!;
        String q = 'q$depth';
        String o = 'o$depth';
        String i = 'i$depth';
        String x = 'x$depth';
        out
          ..writeln('${set}state.list($args);')
          ..writeln('if ($target is List) {')
          ..write(_countIssues(depth))
          ..writeln('List<Object> $q = <Object>[...$path, $key];')
          ..writeln('List<${item.code}> $o = <${item.code}>[];')
          ..writeln('for (int $i = 0; $i < $target.length; $i++) {');
        _conv(
          out,
          field,
          item,
          '$target[$i]',
          q,
          i,
          x,
          depth + 1,
          declare: true,
        );
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
          ..writeln(_badOr(depth, target, o))
          ..writeln('}');
      case DtoKind.map:
        DtoType item = type.item!;
        String q = 'q$depth';
        String o = 'o$depth';
        String k = 'k$depth';
        String x = 'x$depth';
        String entry = 'n$depth';
        out
          ..writeln('${set}state.object($args);')
          ..writeln('if ($target is Map) {')
          ..write(_countIssues(depth))
          ..writeln('List<Object> $q = <Object>[...$path, $key];')
          ..writeln('Map<String, ${item.code}> $o = <String, ${item.code}>{};')
          ..writeln(
            'for (MapEntry<dynamic, dynamic> $entry in $target.entries) {',
          )
          ..writeln("String $k = '\${$entry.key}';");
        _conv(
          out,
          field,
          item,
          '$entry.value',
          q,
          k,
          x,
          depth + 1,
          declare: true,
        );
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
          ..writeln(_badOr(depth, target, o))
          ..writeln('}');
    }
  }

  /// The issue count before the items of a list or map are read.
  String _countIssues(int depth) {
    return runtimeFlags ? 'int b$depth = state.issues.length;\n' : '';
  }

  /// Set [target] to the new list or map [o]. With the DTO flags, a list
  /// or map with a bad item is [invalid], so `state.emptyList()` and the
  /// rules of the field do not run on what is left of it.
  String _badOr(int depth, String target, String o) {
    if (!runtimeFlags) return '$target = $o;';
    return '$target = state.issues.length != b$depth ? invalid : $o;';
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
      ..writeln('state.required($path, $key, _messages);')
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
          ..writeln('List<Object> q = <Object>[...path, $key];')
          ..writeln('for (int i = 0; i < $c.length; i++) {')
          ..writeln('${item.code} v = $c[i];');
        if (item.nullable) items.writeln('if (v != null) {');
        _chain(items, valueRules, item, 'v', 'q', 'i', '');
        if (item.nullable) items.writeln('}');
        items.writeln('}');
      }
      _chain(out, listRules, type, c, 'path', key, items.toString());
    } else {
      _chain(
        out,
        <DtoRule>[...listRules, ...valueRules],
        type,
        c,
        'path',
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
    return 'state.fail($path, $key, IssueCodes.$code, DefaultMessages.$fallback, $v$paramText$message, messages: _messages);';
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
  String _path = 'path';
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
        '${rule.source}.check($v, state.context($path, $key, $v))',
        'state.failRule(${rule.source}, $path, $key, $v, _messages);',
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
      case 'AfterOrEqual':
      case 'BeforeOrEqual':
        String date = rule.stringField('date')!;
        bool after = rule.name.startsWith('After');
        bool orEqual = rule.name.endsWith('OrEqual');
        String code = switch (rule.name) {
          'After' => 'after',
          'Before' => 'before',
          'AfterOrEqual' => 'afterOrEqual',
          _ => 'beforeOrEqual',
        };
        // `!isBefore` is on or after, `!isAfter` is on or before
        String method = after == !orEqual ? 'isAfter' : 'isBefore';
        String not = orEqual ? '!' : '';
        String fail = f(code, code, <String, Object?>{'date': date});
        DtoField? field = DtoReader.dateWords.contains(date)
            ? null
            : DtoReader.dateField(dto, date);
        if (field != null) {
          // another field: no value (or a bad one) passes
          String c = _locals[dto.fields.indexOf(field)];
          return _Check('$c is! DateTime || $not$v.$method($c)', fail);
        }
        String other = switch (date) {
          'now' => 'state.now',
          'today' =>
            'DateTime.utc(state.now.year, state.now.month, state.now.day)',
          'tomorrow' =>
            'DateTime.utc(state.now.year, state.now.month, state.now.day + 1)',
          'yesterday' =>
            'DateTime.utc(state.now.year, state.now.month, state.now.day - 1)',
          _ => '_d${_dates++}',
        };
        if (other.startsWith('_d')) {
          int micros = DtoReader.parseDate(date)!.microsecondsSinceEpoch;
          _statics.add(
            'static final DateTime $other = DateTime.fromMicrosecondsSinceEpoch($micros, isUtc: true);',
          );
        }
        return _Check('$not$v.$method($other)', fail);
      case 'MaxSize':
        String size = rule.stringField('size')!;
        int bytes = DtoReader.sizeOf(size)!;
        return _Check(
          '$v.length <= $bytes',
          f('maxSize', 'maxSize', <String, Object?>{'max': size}),
        );
      case 'MinSize':
        String size = rule.stringField('size')!;
        int bytes = DtoReader.sizeOf(size)!;
        return _Check(
          '$v.length >= $bytes',
          f('minSize', 'minSize', <String, Object?>{'min': size}),
        );
      case 'MimeTypes':
        List<String> types = <String>[
          for (Object? type in _list(rule, 'types')) '$type'.toLowerCase(),
        ];
        return _Check(
          'FileTypes.matchesMimeTypes($v, const ${literal.strings(types)})',
          f('mimeTypes', 'mimes', <String, Object?>{'types': types.join(', ')}),
        );
      case 'Dimensions':
        List<String> limits = <String>[
          for (String key in DtoRule.dimensionFields)
            if (rule.numField(key) != null) '$key: ${rule.numField(key)}',
        ];
        return _Check(
          'ImageSize.fits($v, ${limits.join(', ')})',
          f('dimensions', 'dimensions'),
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
            ? 'Future<void> crossCheck(${dto.name} dto, DtoState state, List<Object> path) async {'
            : 'void crossCheck(${dto.name} dto, DtoState state, List<Object> path) {',
      );
    String wait = async ? 'await ' : '';
    for (DtoField field in dto.fields) {
      _nested(out, field, 'crossCheck', wait);
    }
    if (dto.validate != null) {
      out.writeln(
        '${dto.validateIsAsync ? wait : ''}dto.validate(DtoErrors(state, path));',
      );
    }
    out.writeln('}');
    return out.toString();
  }

  /// Calls [method] (`crossCheck` or `checkAsync`) of each nested DTO
  /// value of [field] that needs it.
  void _nested(StringBuffer out, DtoField field, String method, String wait) {
    DtoType type = field.type;
    DtoType? dtoType = type.dto;
    if (dtoType == null) return;
    DtoFlags nested = flags.flagsOf(dtoType);
    if (!(method == 'crossCheck' ? nested.checks : nested.async)) return;
    String key = _keyLiteral(field);
    String call = '$wait${_ref(dtoType)}.$method';
    out.writeln('{');
    out.writeln('${field.fieldCode} value = dto.${field.name};');
    String value = 'value';
    if (field.maybe) {
      out.writeln('if (value.isPresent) {');
      out.writeln('${type.code} inner = value.value;');
      value = 'inner';
    }
    if (type.nullable) out.writeln('if ($value != null) {');
    _walk(out, type, value, <String>['...path', key], call, 0);
    if (type.nullable) out.writeln('}');
    if (field.maybe) out.writeln('}');
    out.writeln('}');
  }

  /// Calls [call] on each DTO in [value] (not null) of [type], through
  /// lists and maps at any depth. [path] is the path of [value], as the
  /// parts of a list in code.
  void _walk(
    StringBuffer out,
    DtoType type,
    String value,
    List<String> path,
    String call,
    int depth,
  ) {
    if (type.kind == DtoKind.dto) {
      out.writeln("$call($value, state, <Object>[${path.join(', ')}]);");
      return;
    }
    DtoType item = type.item!;
    String x = 'x$depth';
    String index;
    if (type.kind == DtoKind.list) {
      index = 'i$depth';
      out
        ..writeln('for (int $index = 0; $index < $value.length; $index++) {')
        ..writeln('${item.code} $x = $value[$index];');
    } else {
      index = 'e$depth.key';
      out
        ..writeln(
          'for (MapEntry<String, ${item.code}> e$depth in $value.entries) {',
        )
        ..writeln('${item.code} $x = e$depth.value;');
    }
    List<String> inner = <String>[...path, index];
    if (item.nullable) out.writeln('if ($x != null) {');
    _walk(out, item, x, inner, call, depth + 1);
    if (item.nullable) out.writeln('}');
    out.writeln('}');
  }

  // ---------------------------------------------------------------------------
  // Step 4: async rules
  // ---------------------------------------------------------------------------

  String _checkAsync() {
    StringBuffer out = StringBuffer()
      ..writeln('@override')
      ..writeln(
        'Future<void> checkAsync(${dto.name} dto, DtoState state, List<Object> path) async {',
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
          ..writeln('${field.fieldCode} value = dto.${field.name};');
        String value = 'value';
        if (field.maybe) {
          out
            ..writeln('if (value.isPresent) {')
            ..writeln('${type.code} inner = value.value;');
          value = 'inner';
        }
        if (type.nullable) out.writeln('if ($value != null) {');
        for (DtoRule rule in rules) {
          String method = rule.onItems ? 'asyncItems' : 'asyncRule';
          out.writeln(
            'await state.$method(${rule.source}, $value, path, $key, _messages);',
          );
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
      String read = 'map[$key]';
      String value = _from(field.type, read, 0);
      if (field.maybe) {
        String type = field.type.code;
        value =
            'map.containsKey($key) ? Maybe<$type>($value) : const Maybe<$type>.missing()';
      } else if (field.hasDefault) {
        value = 'map.containsKey($key) ? $value : ${field.defaultCode}';
      }
      args.add(field.positional ? value : '${field.name}: $value');
    }
    return '@override\n'
        '${dto.name} fromMap(Map<String, dynamic> map) {\n'
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
    StringBuffer out = StringBuffer();
    if (_serialize) {
      out
        ..writeln('/// The JSON of [${dto.name}] as a map.')
        ..writeln('Map<String, dynamic> \$${dto.name}ToMap(${dto.name} dto) {');
    } else {
      out
        ..writeln('@override')
        ..writeln('Map<String, dynamic> toMap(${dto.name} dto) {');
    }
    Set<String> taken = <String>{'dto', ..._emittedNames, ..._foreignNames};
    List<String> entries = <String>[];
    for (DtoField field in dto.fields) {
      String key = _keyLiteral(field);
      String read = 'dto.${field.name}';
      if (field.maybe) {
        String type = field.type.code;
        String local = safeLocal(field.name, taken);
        entries.add(
          'if ($read case Maybe<$type>(isPresent: true, value: $type $local)) '
          '$key: ${_toValue(field.type, local, 0)}',
        );
        continue;
      }
      String value = _toValue(field.type, read, 0);
      // a conversion that reads the value two times gets a local
      if (read.allMatches(value).length > 1) {
        String local = safeLocal(field.name, taken);
        out.writeln('${field.fieldCode} $local = $read;');
        value = _toValue(field.type, local, 0);
      }
      entries.add('$key: $value');
    }
    out
      ..writeln('return <String, dynamic>{${entries.join(', ')}};')
      ..writeln('}');
    return out.toString();
  }

  /// `writeObject()` writes the JSON of toMap() with no map in between.
  /// The JSON encoder of dox_core calls it for a DTO in a response. It
  /// calls the function of [_writeFunction].
  String _writeObject() {
    return '@override\n'
        'void writeObject(Object object, JsonWriter writer) => '
        '\$write${dto.name}(object as ${dto.name}, writer);\n';
  }

  /// The name of the function that writes the JSON of the DTO [type].
  String _writeRef(DtoType type) => '${type.prefix}\$write${type.name}';

  /// A function `$writeName(Name o, JsonWriter w)` that writes the JSON of
  /// the DTO. It is public, so a DTO in another file calls it directly for
  /// a nested DTO, with no look up of the writer.
  ///
  /// The fixed parts of the JSON (`{"id":`, `,"name":`, `],"tags":[`) are
  /// put together into [JsonRun]s, written 8 bytes at a time. A `Maybe`
  /// field can be left out, so the place of its comma is not fixed: a DTO
  /// with one writes each key with `w.key()`.
  String _writeFunction() {
    StringBuffer out = StringBuffer()
      ..writeln('/// Writes the JSON of [${dto.name}], as `toMap()` gives it.')
      ..writeln(
        'void \$write${dto.name}(${dto.name} dto, JsonWriter writer) {',
      );
    // the locals of the list loops and of the `Maybe` values
    Set<String> taken = <String>{
      'dto',
      'writer',
      'i',
      ..._emittedNames,
      ..._foreignNames,
    };
    List<String> locals = <String>[
      for (DtoField field in dto.fields) safeLocal(field.name, taken),
    ];
    if (dto.fields.any((DtoField field) => field.maybe)) {
      out.writeln('writer.startObject();');
      for (int i = 0; i < dto.fields.length; i++) {
        DtoField field = dto.fields[i];
        String key = 'writer.key(${_keyLiteral(field)});';
        if (field.maybe) {
          String type = field.type.code;
          out.writeln(
            'if (dto.${field.name} case '
            'Maybe<$type>(isPresent: true, value: $type ${locals[i]})) '
            '{ $key ${_writeOne(field.type, locals[i])} }',
          );
        } else {
          String write = _writeOnce(
            field.type,
            'dto.${field.name}',
            locals[i],
            field.fieldCode,
          );
          out.writeln('$key $write');
        }
      }
      out.writeln('writer.endObject();');
    } else {
      _JsonRuns runs = _JsonRuns(this, out)..text('{');
      for (int i = 0; i < dto.fields.length; i++) {
        DtoField field = dto.fields[i];
        runs.text('${i > 0 ? ',' : ''}${jsonEncode(field.key)}:', field.name);
        _writeFast(
          runs,
          field.type,
          'dto.${field.name}',
          locals[i],
          field.fieldCode,
        );
      }
      runs
        ..text('}')
        ..flush();
    }
    out.writeln('}');
    return out.toString();
  }

  /// Writes [value] (of [type]) with [runs]: a list and a nested DTO get
  /// direct calls. Other values go to [_writeValue].
  void _writeFast(
    _JsonRuns runs,
    DtoType type,
    String value,
    String local,
    String typeCode,
  ) {
    String? item = type.kind == DtoKind.list && !type.nullable
        ? _writeItem(type.item!, '$local[i]')
        : null;
    if (item != null) {
      runs
        ..text('[')
        ..code(
          '{ ${type.code} $local = $value; '
          'for (int i = 0; i < $local.length; i++) { '
          'if (i > 0) writer.run(JsonRun.comma); $item } }',
        )
        ..text(']');
      return;
    }
    runs.code(_writeOnce(type, value, local, typeCode));
  }

  /// `true` when the nested DTO [type] has a `$write` function that this
  /// build makes: it has no `toJson()`, it is in the same package, and its
  /// file sees the classes the function needs. A DTO of another package
  /// can come from an older dox_builder. Else the encoder finds its writer.
  ///
  /// A direct call does not look for a cycle. A DTO that holds itself
  /// (`List<Node> children`) with cyclic data ends in a stack overflow,
  /// which the encoder gives as a JSON error. `toMap()` does the same.
  bool _hasWriteFunction(DtoType type) {
    if (!_encoderWrites(type)) return false;
    return switch (type.type.element) {
      InterfaceElement e =>
        _package(e.library.uri) == _package(dto.element.library.uri) &&
            seesDtoWriter(e.library.firstFragment),
      _ => false,
    };
  }

  static String _package(Uri uri) {
    return '${uri.scheme}:${uri.pathSegments.firstOrNull}';
  }

  /// [_writeOne] for a field read. When the call reads [value] two times
  /// (a nullable list that is converted), the value is read once into
  /// [local] of [typeCode].
  String _writeOnce(DtoType type, String value, String local, String typeCode) {
    String call = _writeOne(type, value, local: local);
    if (value.allMatches(call).length < 2) return call;
    return '{ $typeCode $local = $value; ${_writeOne(type, local)} }';
  }

  /// The direct call for [value] (of [type]), else the call of
  /// [_writeValue].
  String _writeOne(DtoType type, String value, {String local = r'$n'}) {
    return _writeItem(type, value) ?? _writeValue(type, value, local: local);
  }

  /// The direct call for [value] (of [type]), or `null` when there is
  /// none.
  String? _writeItem(DtoType type, String value) {
    String dot = type.nullable ? '?.' : '.';
    return switch (type.kind) {
      DtoKind.string => 'writer.string($value);',
      DtoKind.integer => 'writer.integer($value);',
      DtoKind.boolean => 'writer.boolean($value);',
      DtoKind.date => 'writer.dateTime($value);',
      DtoKind.enumName => 'writer.string($value${dot}name);',
      // a subclass at run time is written by its own writer, the same as
      // the map of toMap() and the encoder of the SDK
      DtoKind.dto when _isPlain(type) && _hasWriteFunction(type) =>
        '{ ${type.nonNullCode}? \$v = $value; '
            'if (\$v != null && \$v.runtimeType == ${type.nonNullCode}) '
            '{ ${_writeRef(type)}(\$v, writer); } else { writer.value(\$v); } }',
      DtoKind.dto when _hasWriteFunction(type) =>
        type.nullable
            ? 'if ($value case final \$v?) { ${_writeRef(type)}(\$v, writer); } '
                  'else { writer.value(null); }'
            : '${_writeRef(type)}($value, writer);',
      _ => null,
    };
  }

  /// The writer call for [value] (of [type]). It gives the JSON of
  /// [_toValue]. A nullable value that toMap() changes is read once into
  /// [local] first.
  String _writeValue(DtoType type, String value, {String local = r'$n'}) {
    String dot = type.nullable ? '?.' : '.';
    return switch (type.kind) {
      DtoKind.string => 'writer.string($value);',
      DtoKind.integer => 'writer.integer($value);',
      DtoKind.date => 'writer.dateTime($value);',
      DtoKind.enumName => 'writer.string($value${dot}name);',
      _ when _encoderWrites(type) && !_holdsDto(type) =>
        'writer.value($value);',
      // a field read does not promote to non-null: read it into a local
      _ when type.nullable =>
        '{ ${type.code} $local = $value; '
            'writer.value(${_toValue(type, local, 0)}); }',
      _ => 'writer.value(${_toValue(type, value, 0)});',
    };
  }

  /// `true` when [type] is a DTO or holds one. The encoder writes a DTO
  /// with the writer of its class at run time, so a subclass would put
  /// its extra fields in the JSON. toMap() of the declared class does not.
  bool _holdsDto(DtoType type) {
    return switch (type.kind) {
      DtoKind.dto => true,
      DtoKind.list || DtoKind.map => _holdsDto(type.item!),
      _ => false,
    };
  }

  /// `true` when the JSON encoder writes a value of [type] as toMap()
  /// gives it. A date or an enum in a list is not: toMap() changes it
  /// first. A nested DTO is, because the encoder finds its writer. But a
  /// nested DTO with its own `toJson()` is not: toMap() does not call that
  /// method, and the encoder does.
  bool _encoderWrites(DtoType type) {
    return switch (type.kind) {
      DtoKind.date || DtoKind.enumName => false,
      DtoKind.dto => switch (type.type.element) {
        InterfaceElement e => !hasMethod(e, 'toJson'),
        _ => false,
      },
      DtoKind.list || DtoKind.map => _encoderWrites(type.item!),
      _ => true,
    };
  }

  /// [value] (of [type]) as a JSON-like value.
  String _toValue(DtoType type, String value, int depth) {
    DtoType? item = type.item;
    String x = 'x$depth';
    String? code = switch (type.kind) {
      DtoKind.date => '$value.toIso8601String()',
      DtoKind.enumName => '$value.name',
      DtoKind.dto =>
        _isPlain(type)
            ? '($value.runtimeType == ${type.nonNullCode} '
                  '? ${type.prefix}\$${type.name}ToMap($value) : $value)'
            : '${_ref(type)}.toMap($value)',
      DtoKind.list =>
        _identity(item!)
            ? null
            : '<dynamic>[for (${item.code} $x in $value) '
                  '${_toValue(item, x, depth + 1)}]',
      // `MapEntry.value` does not promote to non-null: a switch gives a
      // local that does
      DtoKind.map =>
        _identity(item!)
            ? null
            : '<String, dynamic>{for (MapEntry<String, ${item.code}> $x '
                  'in $value.entries) $x.key: '
                  '${item.nullable ? 'switch ($x.value) { ${item.code} v$depth => ${_toValue(item, 'v$depth', depth + 1)} }' : _toValue(item, '$x.value', depth + 1)}}',
      _ => null,
    };
    if (code == null) return value;
    return type.nullable ? '$value == null ? null : $code' : code;
  }

  /// `true` when the nested DTO [type] is a plain `@Serialize()` class
  bool _isPlain(DtoType type) {
    DartType dart = type.type;
    return dart is InterfaceType && !_reader.isDto(dart.element);
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
          'JsonSchemaTools.merge(schema, $path, ${rule.source}.toJsonSchema());',
        );
      }
    }
    if (patches.isEmpty) {
      out.writeln('return ${literal.write(jsonSchema)};');
    } else {
      out.writeln(
        'Map<String, dynamic> schema = ${literal.write(jsonSchema)};',
      );
      for (String patch in patches) {
        out.writeln(patch);
      }
      out.writeln('return schema;');
    }
    out.writeln('}');
    return out.toString();
  }
}

class _NoFlags implements DtoFlagsSource {
  const _NoFlags();

  @override
  DtoFlags flagsOf(DtoType type) {
    return const DtoFlags(checks: false, checksAsync: false, async: false);
  }
}

class _Check {
  const _Check(this.condition, this.fail);

  final String condition;
  final String fail;
}

/// Puts the fixed parts of the JSON of a DTO together into runs, between
/// the lines of code that write the values.
class _JsonRuns extends JsonRuns {
  _JsonRuns(DtoWriter writer, StringBuffer out)
    : super(
        writer._class,
        out,
        writer._statics,
        writer._runNames,
        literal: writer.literal,
      );
}

/// Puts fixed parts of JSON together into `JsonRun`s, between the lines
/// of code that write the values. Each run is a `static final` of the
/// class [owner], named after the field of the key it ends with
/// (`_idKey`), else `_end`.
class JsonRuns {
  JsonRuns(
    this.owner,
    this.out,
    this.statics,
    this.names, {
    this.literal = const DartLiteral(),
    this.writer = 'writer',
  });

  /// the name of the `JsonWriter` in the code
  final String writer;

  /// the class that keeps the runs
  final String owner;
  final StringBuffer out;

  /// gets the `static final JsonRun` lines
  final List<String> statics;

  /// the names of the runs so far
  final Set<String> names;
  final DartLiteral literal;
  final StringBuffer _text = StringBuffer();

  /// The field of the last key in the run, for its name.
  String? _field;

  /// Adds the JSON [json] to the run. [field] is the Dart name of the field
  /// when [json] ends with its key.
  void text(String json, [String? field]) {
    _text.write(json);
    if (field != null) _field = field;
  }

  /// Writes the run so far, then the [line] of code.
  void code(String line) {
    flush();
    out.writeln(line);
  }

  /// Writes the run so far as a [JsonRun] of the class.
  void flush() {
    if (_text.isEmpty) return;
    String base = _field == null ? '_end' : '_${_field}Key';
    String name = base;
    for (int n = 2; !names.add(name); n++) {
      name = '$base$n';
    }
    statics.add(
      'static final JsonRun $name = '
      'JsonRun(${literal.string(_text.toString())});',
    );
    out.writeln('$writer.run($owner.$name);');
    _text.clear();
    _field = null;
  }
}
