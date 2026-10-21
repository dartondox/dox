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
///   Future<void> creating(User user) async {
///     user.name = user.name?.trim();
///   }
/// }
///
/// Model.observe<User>(UserObserver());
/// ```
abstract class ModelObserver<T> {
  FutureOr<void> saving(T model) {}
  FutureOr<void> saved(T model) {}
  FutureOr<void> creating(T model) {}
  FutureOr<void> created(T model) {}
  FutureOr<void> updating(T model) {}
  FutureOr<void> updated(T model) {}
  FutureOr<void> deleting(T model) {}
  FutureOr<void> deleted(T model) {}
  FutureOr<void> restoring(T model) {}
  FutureOr<void> restored(T model) {}
  FutureOr<void> forceDeleting(T model) {}
  FutureOr<void> forceDeleted(T model) {}

  /// calls the method for [event]
  FutureOr<void> handle(ModelEvent event, T model) {
    switch (event) {
      case ModelEvent.saving:
        return saving(model);
      case ModelEvent.saved:
        return saved(model);
      case ModelEvent.creating:
        return creating(model);
      case ModelEvent.created:
        return created(model);
      case ModelEvent.updating:
        return updating(model);
      case ModelEvent.updated:
        return updated(model);
      case ModelEvent.deleting:
        return deleting(model);
      case ModelEvent.deleted:
        return deleted(model);
      case ModelEvent.restoring:
        return restoring(model);
      case ModelEvent.restored:
        return restored(model);
      case ModelEvent.forceDeleting:
        return forceDeleting(model);
      case ModelEvent.forceDeleted:
        return forceDeleted(model);
    }
  }
}
