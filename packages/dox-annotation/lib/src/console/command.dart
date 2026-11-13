/// A `dox` command that a package or the app adds.
///
/// ```dart
/// class HelloCommand extends Command {
///   @override
///   String get name => 'hello';
///
///   @override
///   String get description => 'Say hello';
///
///   @override
///   Future<void> run(List<String> args) async {
///     print('Hello ${args.join(' ')}');
///   }
/// }
/// ```
///
/// `dox hello world` calls `run(['world'])`. To fail, set `exitCode`
/// from `dart:io` (eg. `exitCode = 1`) or throw. The `dox` CLI exits with
/// that code when [run] is done.
abstract class Command {
  /// the name after `dox`, like `queue:table`
  String get name;

  /// one line for `dox help`
  String get description;

  /// how to call it, like `make:report <name>`. Shown by `dox help`.
  /// The default is [name].
  String get usage => name;

  /// run the command. [args] are the words after the name.
  Future<void> run(List<String> args);
}
