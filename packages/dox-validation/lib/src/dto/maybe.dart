/// A value that knows "missing" from `null`. Use it for PATCH input.
///
/// ```dart
/// final Maybe<String?> bio; // default: const Maybe.missing()
///
/// if (body.bio.isPresent) user.bio = body.bio.value;
/// ```
class Maybe<T> {
  /// The key was sent, with [value] (which can be `null` when `T` is nullable).
  const Maybe(T value) : isPresent = true, _value = value;

  /// The key was not sent.
  const Maybe.missing() : isPresent = false, _value = null;

  /// `true` when the key was sent.
  final bool isPresent;

  final T? _value;

  /// The value. Throws a [StateError] when the key was missing.
  T get value {
    if (!isPresent) {
      throw StateError('No value: the key was missing. Check isPresent.');
    }
    return _value as T;
  }

  @override
  bool operator ==(Object other) {
    return other is Maybe<T> &&
        other.isPresent == isPresent &&
        other._value == _value;
  }

  @override
  int get hashCode {
    return Object.hash(isPresent, _value);
  }

  @override
  String toString() {
    return isPresent ? 'Maybe($_value)' : 'Maybe.missing()';
  }
}
