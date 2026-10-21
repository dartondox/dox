import '../core/rule.dart';
import '../core/schema.dart';
import '../schemas/object_schema.dart';
import 'rule_chain_schema.dart';
import 'rule_registry.dart';

/// Turns a Laravel style rules map into an [ObjectSchema].
///
/// ```dart
/// RulesSchemaBuilder(registry).build({
///   'email': 'required|email|max:255',
///   'products.*.name': 'required',
/// });
/// ```
///
/// Dotted keys make nested objects. `*` makes a list.
/// The output has only the keys that have rules (like Laravel
/// `validated()`), with their values unchanged.
class RulesSchemaBuilder {
  RulesSchemaBuilder(this.registry);

  /// Where rule names are looked up.
  final RuleRegistry registry;

  /// Flags that are not real rules.
  static const List<String> flags = <String>['nullable', 'sometimes', 'bail'];

  /// Build the schema. [messages] uses keys like `required` or
  /// `email.required`. Old `%s` placeholders still work.
  ObjectSchema build(
    Map<String, String> rules, {
    Map<String, String> messages = const <String, String>{},
  }) {
    _Node root = _Node();
    for (MapEntry<String, String> entry in rules.entries) {
      _Node node = root;
      for (String part in entry.key.split('.')) {
        node = node.childFor(part);
      }
      node.field = entry.key;
      node.rules = entry.value;
    }
    return ObjectSchema(_shape(root, messages));
  }

  Map<String, Schema<Object?>> _shape(
    _Node node,
    Map<String, String> messages,
  ) {
    Map<String, Schema<Object?>> shape = <String, Schema<Object?>>{};
    for (MapEntry<String, _Node> entry in node.children.entries) {
      if (entry.key == '*') {
        continue;
      }
      shape[entry.key] = _schemaFor(entry.value, messages);
    }
    return shape;
  }

  Schema<Object?> _schemaFor(_Node node, Map<String, String> messages) {
    Schema<Object?>? container = _container(node, messages);
    String? text = node.rules;
    if (text == null) {
      return container ?? RuleChainSchema(fieldRules: <Rule<Object?>>[]);
    }
    return _chain(node.field, text, container, messages);
  }

  Schema<Object?>? _container(_Node node, Map<String, String> messages) {
    _Node? wildcard = node.children['*'];
    if (wildcard != null) {
      return ImplicitListSchema(_schemaFor(wildcard, messages));
    }
    if (node.children.isNotEmpty) {
      return ImplicitObjectSchema(ObjectSchema(_shape(node, messages)));
    }
    return null;
  }

  RuleChainSchema _chain(
    String field,
    String text,
    Schema<Object?>? child,
    Map<String, String> messages,
  ) {
    List<_Parsed> parsed = _parse(text);
    List<String> names = <String>[];
    for (_Parsed item in parsed) {
      names.add(item.name);
    }
    List<Rule<Object?>> rules = <Rule<Object?>>[];
    for (_Parsed item in parsed) {
      if (flags.contains(item.name)) {
        continue;
      }
      Rule<Object?> rule = registry.build(RuleDefinition(
        name: item.name,
        args: item.args,
        field: field,
        fieldRules: names,
      ));
      rule.message ??= messages['$field.${item.name}'] ?? messages[item.name];
      rules.add(rule);
    }
    return RuleChainSchema(
      fieldRules: rules,
      allowNull: names.contains('nullable'),
      sometimes: names.contains('sometimes'),
      child: child,
    );
  }

  List<_Parsed> _parse(String text) {
    List<_Parsed> result = <_Parsed>[];
    for (String raw in text.split('|')) {
      String part = raw.trim();
      if (part.isEmpty) {
        continue;
      }
      int colon = part.indexOf(':');
      String name = colon < 0 ? part : part.substring(0, colon);
      String args = colon < 0 ? '' : part.substring(colon + 1);
      result.add(_Parsed(
        name.trim().toLowerCase(),
        args.isEmpty ? <String>[] : args.split(','),
      ));
    }
    return result;
  }
}

class _Parsed {
  _Parsed(this.name, this.args);

  final String name;
  final List<String> args;
}

class _Node {
  final Map<String, _Node> children = <String, _Node>{};
  String field = '';
  String? rules;

  _Node childFor(String key) {
    _Node? existing = children[key];
    if (existing != null) {
      return existing;
    }
    _Node created = _Node();
    children[key] = created;
    return created;
  }
}
