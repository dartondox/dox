import 'dart:async';

/// The events a model fires on save(), delete(), restore() and forceDelete().
enum ModelEvent {
  saving,
  saved,
  creating,
  created,
  updating,
  updated,
  deleting,
  deleted,
  restoring,
  restored,
  forceDeleting,
  forceDeleted,
}

/// Throw this in a "before" hook (saving, creating, updating, deleting,
/// restoring, forceDeleting) to stop the operation.
/// save(), delete(), restore() and forceDelete() then return false.
///
/// ```
/// @override
/// Future<void> onCreating() async {
///   if (email == null) throw CancelModelEvent('email is required');
/// }
/// ```
class CancelModelEvent implements Exception {
  final String? message;

  const CancelModelEvent([this.message]);

  @override
  String toString() => 'CancelModelEvent: ${message ?? ''}';
}

/// Listens to the events of one model class.
/// Override only the methods you need.
///
/// ```
/// class UserObserver extends ModelObserver<User> {
///   @override
///   Future<void> onCreating(User user) async {
///     user.name = user.name?.trim();
///   }
/// }
///
/// Model.observe<User>(UserObserver());
/// ```
abstract class ModelObserver<T> {
  FutureOr<void> onSaving(T model) {}
  FutureOr<void> onSaved(T model) {}
  FutureOr<void> onCreating(T model) {}
  FutureOr<void> onCreated(T model) {}
  FutureOr<void> onUpdating(T model) {}
  FutureOr<void> onUpdated(T model) {}
  FutureOr<void> onDeleting(T model) {}
  FutureOr<void> onDeleted(T model) {}
  FutureOr<void> onRestoring(T model) {}
  FutureOr<void> onRestored(T model) {}
  FutureOr<void> onForceDeleting(T model) {}
  FutureOr<void> onForceDeleted(T model) {}

  /// calls the method for [event]
  FutureOr<void> handle(ModelEvent event, T model) {
    switch (event) {
      case ModelEvent.saving:
        return onSaving(model);
      case ModelEvent.saved:
        return onSaved(model);
      case ModelEvent.creating:
        return onCreating(model);
      case ModelEvent.created:
        return onCreated(model);
      case ModelEvent.updating:
        return onUpdating(model);
      case ModelEvent.updated:
        return onUpdated(model);
      case ModelEvent.deleting:
        return onDeleting(model);
      case ModelEvent.deleted:
        return onDeleted(model);
      case ModelEvent.restoring:
        return onRestoring(model);
      case ModelEvent.restored:
        return onRestored(model);
      case ModelEvent.forceDeleting:
        return onForceDeleting(model);
      case ModelEvent.forceDeleted:
        return onForceDeleted(model);
    }
  }
}
