import 'dart:convert';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';

import '../dto/dto_model.dart';
import '../dto/dto_writer.dart';
import '../openapi/dart_literal.dart';
import '../util.dart';
import 'serialize_reader.dart';

/// Writes the JSON writer of one `@Serialize()` serializer, from its
/// [SerializerPlan].
///
/// The writer does what `convert()` does, in the same order: the local
/// variables first, then each value of the map, each one time. The keys
/// and the brackets are put together into `JsonRun`s. A value gets the
/// writer call of its static type.
class SerializerWriter {
  SerializerWriter(
    this.plan,
    this.reader, {
    this.literal = const DartLiteral(),
  });

  final SerializerPlan plan;
  final SerializeReader reader;
  final DartLiteral literal;

  final List<String> _statics = <String>[];
  final Set<String> _runNames = <String>{};

  /// names that the generated code declares
  static const Set<String> _emittedNames = <String>{
    'i',
    'items',
    'JsonRun',
    'JsonWriter',
    'Serializer',
    'SerializeWriter',
    'List',
    'int',
  };

  late final Set<String> _taken = <String>{...plan.taken, ..._emittedNames};
  late final String _receiver = safeLocal('serializer', _taken);
  late final String _writer = safeLocal('writer', _taken);
  late final CodeCopier _copier = CodeCopier(plan.element, _receiver);

  String get _class => '_\$${plan.name}Writer';

  LibraryElement get _library => plan.element.library;

  /// The whole generated code of the serializer.
  Future<String> write() async {
    String name = plan.name;
    bool inline = plan.inline;
    // `$item`: no class name has a `$`, so no other function has this name
    String item = '${inline ? '' : '_'}\$write$name\$item';
    String self = inline ? '' : 'serializer, ';
    StringBuffer body = StringBuffer();
    for (VariableDeclarationStatement local in plan.locals) {
      body.writeln(_copier.copy(local));
    }
    JsonRuns runs = JsonRuns(
      _class,
      body,
      _statics,
      _runNames,
      literal: literal,
      writer: _writer,
    );
    await _map(runs, plan.map);
    runs.flush();
    String listStart = _run('_listStart', '[');
    String listEnd = _run('_listEnd', ']');
    // Dox finds the writer by the exact class of the object, so a subclass
    // with its own convert() never gets it. A mixin on the class with a
    // writeJson() would skip the look-up, but it must check the class of
    // the object too, and that costs the same as the look-up.
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
        'Object? toJsonValue(Object object) => (object as $name).toJson();',
      )
      ..writeln('}')
      ..writeln()
      ..writeln('/// Writes the JSON of [$name], as `toJson()` gives it.')
      ..writeln('void \$write$name($name serializer, JsonWriter writer) {')
      ..writeln(
        'List<${plan.payloadType}>? items = Serializer.listOf(serializer);',
      )
      ..writeln('if (items == null) {')
      ..writeln('if (Serializer.hasItem(serializer)) {')
      ..writeln('$item(${self}Serializer.itemOf(serializer), writer);')
      ..writeln('} else {')
      ..writeln('writer.value(null);')
      ..writeln('}')
      ..writeln('return;')
      ..writeln('}')
      ..writeln('writer.run($_class.$listStart);')
      ..writeln('for (int i = 0; i < items.length; i++) {')
      ..writeln('if (i > 0) writer.run(JsonRun.comma);')
      ..writeln('$item(${self}items[i], writer);')
      ..writeln('}')
      ..writeln('writer.run($_class.$listEnd);')
      ..writeln('}')
      ..writeln()
      ..writeln('/// Writes the map of `convert()` of [$name].')
      ..writeln(
        'void $item(${inline ? '' : '$name $_receiver, '}'
        '${plan.itemType} ${plan.itemName}, JsonWriter $_writer) {',
      )
      ..write(body)
      ..writeln('}');
    return out.toString();
  }

  String _run(String base, String json) {
    String name = base;
    for (int n = 2; !_runNames.add(name); n++) {
      name = '$base$n';
    }
    _statics.add(
      'static final JsonRun $name = JsonRun(${literal.string(json)});',
    );
    return name;
  }

  /// Writes the map literal [map]: its keys go into [runs].
  Future<void> _map(JsonRuns runs, SetOrMapLiteral map) async {
    runs.text('{');
    bool first = true;
    for (CollectionElement element in map.elements) {
      MapLiteralEntry entry = element as MapLiteralEntry;
      String key = (entry.key as StringLiteral).stringValue!;
      String field = _fieldName(key);
      runs.text('${first ? '' : ','}${jsonEncode(key)}:', field);
      first = false;
      Expression value = entry.value.unParenthesized;
      if (value is SetOrMapLiteral && value.isMap) {
        await _map(runs, value);
        continue;
      }
      await _value(runs, entry.value, field);
    }
    runs.text('}');
  }

  /// The name of a key in Dart, for its run and its local, like
  /// `loginCount` for `login_count`.
  String _fieldName(String key) {
    List<String> words = <String>[
      for (String word in key.split(RegExp(r'[^A-Za-z0-9]+')))
        if (word.isNotEmpty) word,
    ];
    String name = <String>[
      for (int i = 0; i < words.length; i++)
        i == 0 ? lcFirst(words[i]) : ucFirst(words[i]),
    ].join();
    if (name.isEmpty || RegExp(r'^[0-9]').hasMatch(name)) {
      name = 'value$name';
    }
    return name;
  }

  /// Writes one value of the map, by its static type.
  Future<void> _value(JsonRuns runs, Expression node, String field) async {
    String code = _copier.copy(node);
    String wrapped = _wrap(node, code);
    DartType? type = node.staticType;
    String w = _writer;
    if (type is! InterfaceType) {
      runs.code('$w.value($code);');
      return;
    }
    String? scalar = _scalar(type);
    if (scalar != null) {
      runs.code('$w.$scalar($code);');
      return;
    }
    bool nullable = type.nullabilitySuffix == NullabilitySuffix.question;
    String v = safeLocal(r'$v', <String>{..._taken});
    if (await _inline(runs, node, field)) return;
    String? direct = await _directCall(node, type);
    if (direct != null) {
      if (_makesExact(node)) {
        runs.code('$direct($code, $w);');
      } else {
        // a subclass at run time has its own writer: the encoder finds it
        String exact = typeCode(type, _library).replaceFirst('?', '');
        runs.code(
          '{ $exact? $v = $code; '
          'if ($v != null && $v.runtimeType == $exact) { $direct($v, $w); } '
          'else { $w.value($v); } }',
        );
      }
      return;
    }
    if (_isJsonWritable(type)) {
      runs.code(
        nullable
            ? 'if ($wrapped case final $v?) { $v.writeJson($w); } '
                  'else { $w.value(null); }'
            : '$wrapped.writeJson($w);',
      );
      return;
    }
    if (type.isDartCoreList && !nullable) {
      DartType item = type.typeArguments.first;
      String? each = item is InterfaceType ? _scalar(item) : null;
      if (each != null) {
        String local = safeLocal(field, _taken);
        runs
          ..text('[')
          ..code(
            '{ ${typeCode(type, _library)} $local = $code; '
            'for (int i = 0; i < $local.length; i++) { '
            'if (i > 0) $w.run(JsonRun.comma); $w.$each($local[i]); } }',
          )
          ..text(']');
        return;
      }
    }
    runs.code('$w.value($code);');
  }

  /// Writes `Name(x)` of a serializer with an inline plan with no
  /// serializer object: `$writeName$item(x, writer)` for one item, a loop
  /// for a list. Returns false for any other value.
  Future<bool> _inline(JsonRuns runs, Expression node, String field) async {
    Expression made = node.unParenthesized;
    if (made is! InstanceCreationExpression) return false;
    if (made.constructorName.name != null || !_makesExact(made)) {
      return false;
    }
    DartType type = made.staticType!;
    if (type is! InterfaceType) return false;
    InterfaceElement element = type.element;
    if (element is! ClassElement || !reader.reader.isSerialize(element)) {
      return false;
    }
    if (!DtoReader.isSerializer(element)) return false;
    SerializerPlan? nested = (await reader.serializer(element)).plan;
    if (nested == null || !nested.inline) return false;
    NodeList<Argument> args = made.argumentList.arguments;
    if (args.length != 1 || args.first is NamedArgument) return false;
    String? prefix = generatedPrefix(
      _library,
      element,
      '\$write${element.displayName}\$item',
    );
    if (prefix == null) return false;
    Expression arg = args.first.argumentExpression;
    DartType? data = arg.staticType;
    if (data == null) return false;
    String call = '$prefix\$write${element.displayName}\$item';
    String code = _copier.copy(arg);
    String w = _writer;
    TypeSystem types = _library.typeSystem;
    DartType item = nested.payload;
    if (types.isSubtypeOf(data, item)) {
      runs.code('$call($code, $w);');
      return true;
    }
    if (data.nullabilitySuffix == NullabilitySuffix.question &&
        types.isSubtypeOf(types.promoteToNonNull(data), item)) {
      String v = safeLocal(r'$v', <String>{..._taken});
      runs.code(
        'if (${_wrap(arg, code)} case final $v?) { $call($v, $w); } '
        'else { $w.value(null); }',
      );
      return true;
    }
    if (data is InterfaceType &&
        data.isDartCoreList &&
        data.nullabilitySuffix == NullabilitySuffix.none &&
        types.isSubtypeOf(data.typeArguments.first, item) &&
        !types.isSubtypeOf(data, item)) {
      String local = safeLocal(field, _taken);
      runs
        ..text('[')
        ..code(
          '{ ${typeCode(data, _library)} $local = $code; '
          'for (int i = 0; i < $local.length; i++) { '
          'if (i > 0) $w.run(JsonRun.comma); $call($local[i], $w); } }',
        )
        ..text(']');
      return true;
    }
    return false;
  }

  /// `true` when [node] makes an object of exactly its static type: a
  /// generative constructor. A factory can give a subclass.
  static bool _makesExact(Expression node) {
    Expression made = node.unParenthesized;
    return made is InstanceCreationExpression &&
        made.constructorName.element?.isFactory == false;
  }

  /// The `$write` function of the `@Serialize()` class of [type], to call
  /// directly for the value [node], or null.
  ///
  /// A serializer only when [node] makes it (`PostSerializer(m.posts)`): a
  /// subclass could have another `convert()`. The caller checks the class
  /// of a plain class value at run time.
  Future<String?> _directCall(Expression node, InterfaceType type) async {
    InterfaceElement element = type.element;
    if (element is! ClassElement) return null;
    if (!await reader.hasWriter(element)) return null;
    if (DtoReader.isSerializer(element) && !_makesExact(node)) return null;
    String name = '\$write${element.displayName}';
    String? prefix = generatedPrefix(_library, element, name);
    if (prefix == null) return null;
    return '$prefix$name';
  }

  /// The writer method of a text, a whole number, a `bool` or a date. Its
  /// JSON is the same as the JSON encoder gives for the value.
  static String? _scalar(InterfaceType type) {
    if (type.isDartCoreString) return 'string';
    if (type.isDartCoreInt) return 'integer';
    if (type.isDartCoreBool) return 'boolean';
    if (type.element.library.isDartCore &&
        type.element.displayName == 'DateTime') {
      return 'dateTime';
    }
    return null;
  }

  static bool _isJsonWritable(InterfaceType type) {
    for (InterfaceType above in type.allSupertypes) {
      InterfaceElement element = above.element;
      if (element.displayName == 'JsonWritable' &&
          element.library.uri.toString().startsWith(
            'package:dox_annotation/',
          )) {
        return true;
      }
    }
    return false;
  }

  /// [code] in brackets, unless it is a plain name or a call
  static String _wrap(Expression node, String code) {
    Expression plain = node.unParenthesized;
    if (plain is Identifier ||
        plain is MethodInvocation ||
        plain is PropertyAccess ||
        plain is InstanceCreationExpression ||
        plain is ParenthesizedExpression) {
      return code;
    }
    return '($code)';
  }
}
