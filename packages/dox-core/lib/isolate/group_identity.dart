import 'dart:isolate';

/// Who a server isolate is, when it runs in its own isolate group
/// (`CoreFlags.isolateGroups`).
///
/// A group starts with the `main()` of the app, which can not get a
/// message. So the identity travels in the `debugName` of the isolate:
/// `dox-group-<isolateId>-<isolateCount>-<primaryNativePort>`. The
/// primary port is where the isolate sends its own port to say hello.
class GroupIdentity {
  const GroupIdentity(this.isolateId, this.isolateCount, this.primaryPort);

  static const String prefix = 'dox-group-';

  static final RegExp _shape = RegExp(r'^dox-group-(\d+)-(\d+)-(-?\d+)$');

  final int isolateId;
  final int isolateCount;

  /// the native port id of the primary isolate that waits for the hello
  final int primaryPort;

  /// The identity of this isolate, or null when it is not a group worker.
  static GroupIdentity? get current => parse(Isolate.current.debugName);

  /// The identity in [name], or null when [name] has another shape.
  static GroupIdentity? parse(String? name) {
    if (name == null) return null;
    // the port id can be negative, so the last part may start with `-`
    RegExpMatch? match = _shape.firstMatch(name);
    if (match == null) return null;
    int? id = int.tryParse(match.group(1)!);
    int? count = int.tryParse(match.group(2)!);
    int? port = int.tryParse(match.group(3)!);
    if (id == null || count == null || port == null) return null;
    if (id < 2 || count < id) return null;
    return GroupIdentity(id, count, port);
  }

  String get debugName => '$prefix$isolateId-$isolateCount-$primaryPort';
}
