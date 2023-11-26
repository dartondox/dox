import 'shared_mixin.dart';

mixin SoftDeletes<T> implements SharedMixin<T> {
  @override
  bool isSoftDeletes = true;
}
