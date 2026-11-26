import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:covfuzz/covfuzz.dart';
import 'package:dox_core/dox_core.dart';

/// A fuzz target for a parser that reads a stream. covfuzz can only call
/// synchronous code, so this class has its own loop. It has no coverage
/// feedback: an input that the parser takes with no error is kept and
/// changed again.
///
/// A run fails on the first input where [check] throws an error that is
/// not a 4xx answer, or does not end in 5 seconds.
abstract class AsyncFuzzTarget {
  const AsyncFuzzTarget();

  /// the name of the target, used for the folder of failed inputs
  String get name;

  /// valid inputs. The changes start from these.
  List<Uint8List> get seeds;

  /// Give [input] to the parser. [random] cuts the input into chunks.
  Future<void> check(Uint8List input, Random random);

  /// true when [error] is an answer to bad input (a 4xx), not a 500
  bool isClean(Object error) => error is IHttpException && error.code < 500;

  /// [input] in 1 to 4 chunks, cut at random places
  List<Uint8List> chunks(Uint8List input, Random random) {
    List<int> cuts = <int>[
      for (int i = random.nextInt(4); i > 0; i--)
        random.nextInt(input.length + 1),
    ]..sort();
    List<Uint8List> out = <Uint8List>[];
    int from = 0;
    for (int cut in <int>[...cuts, input.length]) {
      out.add(Uint8List.sublistView(input, from, cut));
      from = cut;
    }
    return out;
  }

  /// The first argument is the random seed (default: the time), the second
  /// is the seconds to run (default 60).
  Future<void> run(List<String> args) async {
    int seed = args.isNotEmpty
        ? int.parse(args[0])
        : DateTime.now().millisecondsSinceEpoch ~/ 1000;
    int seconds = args.length > 1 ? int.parse(args[1]) : 60;
    stdout.writeln('$name: seed $seed');
    Random random = Random(seed);

    /// the seeds are valid inputs: an error here is a broken target
    for (Uint8List input in seeds) {
      await check(input, random);
    }

    List<Uint8List> pool = <Uint8List>[...seeds];
    Stopwatch watch = Stopwatch()..start();
    int runs = 0;
    while (watch.elapsed.inSeconds < seconds) {
      Uint8List input = mutateBytes(pool[random.nextInt(pool.length)], random);
      runs++;
      try {
        await _guarded(input, random).timeout(const Duration(seconds: 5));
        if (pool.length < 256) pool.add(input);
      } catch (error, stackTrace) {
        if (!isClean(error)) _fail(input, error, stackTrace);
      }
    }
    stdout.writeln('runs=$runs elapsed=${watch.elapsedMilliseconds}ms');
    stdout.writeln('CLEAN: only 4xx answers.');
    exit(0);
  }

  /// [check], where an error that no code catches (thrown in a stream
  /// callback) also fails the input. Without the zone such an error stops
  /// the process, and the input is not known.
  Future<void> _guarded(Uint8List input, Random random) {
    Completer<void> done = Completer<void>();
    runZonedGuarded(
      () {
        check(input, random).then(
          (_) {
            if (!done.isCompleted) done.complete();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!done.isCompleted) done.completeError(error, stackTrace);
          },
        );
      },
      (Object error, StackTrace stackTrace) {
        if (!done.isCompleted) {
          done.completeError(_Uncaught(error), stackTrace);
        }
      },
    );
    return done.future;
  }

  Never _fail(Uint8List input, Object error, StackTrace stackTrace) {
    Directory folder = Directory('fuzz/artifacts/$name')
      ..createSync(recursive: true);
    File file = File('${folder.path}/crash-${input.hashCode.toUnsigned(32)}')
      ..writeAsBytesSync(input);
    stdout.writeln('FAILED: ${error.runtimeType}: $error');
    stdout.writeln('$stackTrace');
    stdout.writeln('input (${input.length} bytes) in ${file.path}');
    stdout.writeln('input as base64: ${base64.encode(input)}');
    exit(1);
  }
}

/// an error that no code caught. It is never a clean answer.
class _Uncaught {
  _Uncaught(this.error);

  final Object error;

  @override
  String toString() => 'not caught: ${error.runtimeType}: $error';
}
