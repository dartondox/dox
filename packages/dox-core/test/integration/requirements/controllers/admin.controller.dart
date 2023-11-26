import 'package:dox_core/dox_core.dart';

class AdminController {
  /// GET /admins
  Future<String> index(DoxRequest req) async {
    return 'GET /admins';
  }

  /// GET /admins/create
  String create(DoxRequest req) {
    return 'GET /admins/create';
  }

  /// POST /admins
  Future<String> store(DoxRequest req) async {
    return 'POST /admins';
  }

  /// GET /admins/{id}
  Future<String> show(DoxRequest req, String id) async {
    return 'GET /admins/{id}';
  }

  /// GET /admins/{id}/edit
  Future<String> edit(DoxRequest req, String id) async {
    return 'GET /admins/{id}/edit';
  }

  /// PUT|PATCH /admins/{id}
  Future<String> update(DoxRequest req, String id) async {
    return 'PUT|PATCH /admins/{id}';
  }

  /// DELETE /admins/{id}
  Future<String> destroy(DoxRequest req, String id) async {
    return 'DELETE /admins/{id}';
  }
}
