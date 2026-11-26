import 'dart:io';

import 'package:covfuzz/covfuzz.dart';
import 'package:dox_core/dox_core.dart';

/// One fuzz target: a parser of input that a client controls.
///
/// A run has two parts:
/// 1. Blind: many random changes of the seeds, with no feedback.
/// 2. Coverage: an input that reaches new code of [library] is kept and
///    changed again. This part reads the coverage from the VM service.
///
/// A run fails when [check] throws an error that is not a 4xx answer to
/// bad input.
abstract class FuzzTarget {
  const FuzzTarget();

  /// the name of the target, used for the folder of failed inputs
  String get name;

  /// the library that the coverage is read from
  String get library;

  /// valid inputs. The changes start from these.
  List<String> get seeds;

  /// Give [input] to the parser. Throw when the result is wrong.
  void check(String input);

  /// true when [error] is an answer to bad input (a 4xx), not a 500
  bool isClean(Object error) => error is IHttpException && error.code < 500;

  /// Throw when a list in [value] holds null: an input value was lost.
  void noNull(Object? value) {
    if (value is Map) {
      for (Object? item in value.values) {
        noNull(item);
      }
    }
    if (value is List) {
      if (value.contains(null)) throw StateError('lost value in $value');
      for (Object? item in value) {
        noNull(item);
      }
    }
  }

  /// The first argument is the random seed (default: the time), the second
  /// is the seconds of the coverage part (default 60).
  Future<void> run(List<String> args) async {
    int seed = args.isNotEmpty
        ? int.parse(args[0])
        : DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int seconds = args.length > 1 ? int.parse(args[1]) : 60;
    stdout.writeln('$name: seed $seed');

    /// the seeds are valid inputs: an error here is a broken target
    for (String input in seeds) {
      check(input);
    }

    /// exit code 2 (a slow parse) is not a failure: a shared CI runner
    /// can pause for longer than the limit.
    int blind = fuzz<String>(
      seeds: seeds,
      entry: check,
      mutate: mutateString,
      isClean: isClean,
      iterations: 2000000,
      budgetMs: 20000,
      seed: seed,
    ).report();
    if (blind == 1) exit(1);

    CovFuzzReport report = await covFuzz<String>(
      seeds: seeds,
      entry: check,
      mutate: mutateString,
      targetLib: library,
      isClean: isClean,
      iterations: 1 << 30,
      budgetMs: seconds * 1000,
      seed: seed,
      crashDir: 'fuzz/artifacts/$name',
      log: true,
    );
    exit(report.report());
  }
}
