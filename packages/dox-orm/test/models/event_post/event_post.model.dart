import 'package:dox_orm/dox_orm.dart';

part 'event_post.model.g.dart';

/// a model with every hook, for the model events test
@DoxModel(table: 'event_posts', softDelete: true)
class EventPost extends EventPostGenerator {
  /// hooks write here, so the test can check the order
  static List<String> log = <String>[];

  /// the hook named here throws CancelModelEvent
  static String? cancelOn;

  /// the hook named here throws an error
  static String? failOn;

  @Column()
  String? title;

  @Column(name: 'deleted_at')
  DateTime? deletedAt;

  void _log(String name) {
    log.add(name);
    if (cancelOn == name) throw CancelModelEvent(name);
    if (failOn == name) throw StateError(name);
  }

  @override
  Future<void> onSaving() async => _log('saving');
  @override
  Future<void> onSaved() async => _log('saved');
  @override
  Future<void> onCreating() async {
    title = title?.trim();
    _log('creating');
  }

  @override
  Future<void> onCreated() async => _log('created');
  @override
  Future<void> onUpdating() async => _log('updating');
  @override
  Future<void> onUpdated() async => _log('updated');
  @override
  Future<void> onDeleting() async => _log('deleting');
  @override
  Future<void> onDeleted() async => _log('deleted');
  @override
  Future<void> onRestoring() async => _log('restoring');
  @override
  Future<void> onRestored() async => _log('restored');
  @override
  Future<void> onForceDeleting() async => _log('forceDeleting');
  @override
  Future<void> onForceDeleted() async => _log('forceDeleted');
}
