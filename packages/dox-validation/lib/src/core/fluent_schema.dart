import 'refine_rules.dart';
import 'rule.dart';
import 'schema.dart';

/// Shared fluent methods. Each method returns a new copy of the schema,
/// so a base schema can be reused safely.
///
/// [S] is the schema class itself, so `v.string().refine(...).min(3)`
/// still has the string methods.
mixin FluentSchema<S extends Schema<O>, O> on Schema<O> {
  /// Add a reusable [Rule].
  S use(Rule<O> rule) {
    Schema<O> next = copySchema();
    next.rules.add(rule);
    return next as S;
  }

  /// Add a one-off check. [path] is added to the issue path, which is
  /// handy for object checks like "passwords must match".
  S refine(
    bool Function(O value) check, {
    String? message,
    String code = 'custom',
    List<Object> path = const <Object>[],
  }) {
    return use(RefineRule<O>(
      check: check,
      message: message,
      code: code,
      extraPath: path,
    ));
  }

  /// Add an async one-off check, like "email is unique".
  /// Use `parseAsync` with it.
  S refineAsync(
    Future<bool> Function(O value) check, {
    String? message,
    String code = 'custom',
    List<Object> path = const <Object>[],
  }) {
    return use(RefineRule<O>(
      asyncCheck: check,
      message: message,
      code: code,
      extraPath: path,
    ));
  }

  /// Add a check that can add many issues with `context.addIssue()`.
  S superRefine(void Function(O value, RuleContext context) check) {
    return use(SuperRefineRule<O>(check: check));
  }

  /// Async version of [superRefine].
  S superRefineAsync(
    Future<void> Function(O value, RuleContext context) check,
  ) {
    return use(SuperRefineRule<O>(asyncCheck: check));
  }

  /// Add a description for docs (JSON Schema `description`).
  S describe(String text) {
    Schema<O> next = copySchema();
    next.description = text;
    return next as S;
  }

  /// Add an example value for docs (JSON Schema `examples`).
  S example(Object? value) {
    Schema<O> next = copySchema();
    next.examples.add(value);
    return next as S;
  }
}
