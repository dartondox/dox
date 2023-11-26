import 'package:dox_annotation/dox_annotation.dart';

abstract class IAuth {
  Future<void> verifyToken(IDoxRequest req);
  bool isLoggedIn();
  T? user<T>();
  Map<String, dynamic>? toJson();
}
