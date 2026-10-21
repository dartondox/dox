import '../core/rule.dart';
import 'laravel_rule_builders.dart';

/// Builds one [Rule] from a rule text like `min:3`.
typedef RuleBuilder = Rule<Object?> Function(RuleDefinition definition);

/// One parsed rule from a rule string, like `between:1,10`.
class RuleDefinition {
  RuleDefinition({
    required this.name,
    required this.args,
    required this.field,
    required this.fieldRules,
  });

  /// Rule name, like `between`.
  final String name;

  /// Rule arguments, like `['1', '10']`.
  final List<String> args;

  /// The field key from the rules map, like `products.*.name`.
  final String field;

  /// Names of all rules on the same field. Used for type hints,
  /// for example `min` checks length when the field also has `string`.
  final List<String> fieldRules;

  /// The first argument, or [fallback] when there is none.
  String arg(int index, [String fallback = '']) {
    if (index < args.length) {
      return args[index];
    }
    return fallback;
  }
}

/// Holds the rule builders used by `v.fromRules()`.
///
/// Add your own rule:
/// ```dart
/// v.registerRule('unique', (RuleDefinition d) {
///   return UniqueRule(table: d.arg(0));
/// });
/// ```
class RuleRegistry {
  RuleRegistry();

  /// A registry with all built-in Laravel style rules.
  factory RuleRegistry.withDefaults() {
    RuleRegistry registry = RuleRegistry();
    registry._builders.addAll(LaravelRuleBuilders.all());
    return registry;
  }

  final Map<String, RuleBuilder> _builders = <String, RuleBuilder>{};

  /// Add or replace a rule.
  void register(String name, RuleBuilder builder) {
    _builders[name.toLowerCase()] = builder;
  }

  /// `true` when a rule with [name] exists.
  bool has(String name) {
    return _builders.containsKey(name.toLowerCase());
  }

  /// Names of all rules.
  List<String> get names {
    return _builders.keys.toList();
  }

  /// Build a rule. Throws [ArgumentError] for an unknown rule name.
  Rule<Object?> build(RuleDefinition definition) {
    RuleBuilder? builder = _builders[definition.name];
    if (builder == null) {
      throw ArgumentError(
        'Unknown validation rule "${definition.name}" on "${definition.field}".',
      );
    }
    return builder(definition);
  }
}
