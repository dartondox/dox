/// Marks a value that is not there at all, like a missing map key.
///
/// It is different from `null`. Pass [undefined] to `parse` to test
/// a missing value at the top level.
class Undefined {
  const Undefined();

  @override
  String toString() {
    return 'undefined';
  }
}

/// The single [Undefined] value.
const Undefined undefined = Undefined();

/// Marks a value that failed its type check.
///
/// Only schema classes return it. Users do not see it.
class Invalid {
  const Invalid();
}

/// The single [Invalid] value.
const Invalid invalid = Invalid();
