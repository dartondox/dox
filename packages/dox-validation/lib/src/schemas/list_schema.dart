import '../constants/default_messages.dart';
import '../constants/issue_codes.dart';
import '../core/fluent_schema.dart';
import '../core/parse_state.dart';
import '../core/schema.dart';
import '../core/sentinels.dart';
import '../rules/collection_rules.dart';

/// `isAsync` per schema. A schema does not change after it is built,
/// so the tree is walked only once, not on every parse.
final Expando<bool> _isAsyncCache = Expando<bool>('isAsync');

/// Schema for a list where every item matches [item]. Made by `v.list()`.
class ListSchema<T> extends BaseSchema<List<T>>
    with FluentSchema<ListSchema<T>, List<T>> {
  ListSchema(this.item);

  /// Schema for each item.
  final Schema<T> item;

  @override
  bool get isAsync {
    return _isAsyncCache[this] ??= super.isAsync || item.isAsync;
  }

  /// At least [count] items.
  ListSchema<T> min(int count, {String? message}) {
    return use(MinItemsRule<T>(count, message: message));
  }

  /// At most [count] items.
  ListSchema<T> max(int count, {String? message}) {
    return use(MaxItemsRule<T>(count, message: message));
  }

  /// At least one item.
  ListSchema<T> nonEmpty({String? message}) {
    return min(1, message: message);
  }

  @override
  Object? parseType(Object? input, ParseState state, List<Object> path) {
    if (input is! List) {
      _typeIssue(input, state, path);
      return invalid;
    }
    List<T> output = <T>[];
    for (int i = 0; i < input.length; i++) {
      Object? value = item.parseValue(input[i], state, <Object>[...path, i]);
      _add(output, value);
    }
    return output;
  }

  @override
  Future<Object?> parseTypeAsync(
    Object? input,
    ParseState state,
    List<Object> path,
  ) async {
    if (input is! List) {
      _typeIssue(input, state, path);
      return invalid;
    }
    List<T> output = <T>[];
    for (int i = 0; i < input.length; i++) {
      Object? value = await item.parseValueAsync(input[i], state, <Object>[
        ...path,
        i,
      ]);
      _add(output, value);
    }
    return output;
  }

  void _add(List<T> output, Object? value) {
    if (value is Invalid || value is Undefined) {
      return;
    }
    output.add(value as T);
  }

  void _typeIssue(Object? input, ParseState state, List<Object> path) {
    addTypeIssue(
      code: IssueCodes.array,
      fallback: DefaultMessages.array,
      input: input,
      state: state,
      path: path,
    );
  }

  @override
  Map<String, dynamic> jsonSchemaBase() {
    return <String, dynamic>{'type': 'array', 'items': item.toJsonSchema()};
  }

  @override
  ListSchema<T> copySchema() {
    return copyBaseInto(ListSchema<T>(item));
  }
}
