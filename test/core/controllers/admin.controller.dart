import 'package:dox_core/dox_core.dart';

class AdminController {
  /// GET /admins
  index(DoxRequest req) async {
    return 'GET /admins';
  }

  /// GET /admins/create
  create(DoxRequest req) {
    return 'GET /admins/create';
  }

  /// POST /admins
  store(DoxRequest req) async {
    return 'POST /admins';
  }

  /// GET /admins/{id}
  show(DoxRequest req, String id) async {
    return 'GET /admins/{id}';
  }

  /// GET /admins/{id}/edit
  edit(DoxRequest req, String id) async {
    return 'GET /admins/{id}/edit';
  }

  /// PUT|PATCH /admins/{id}
  update(DoxRequest req, String id) async {
    return 'PUT|PATCH /admins/{id}';
  }

  /// DELETE /admins/{id}
  destroy(DoxRequest req, String id) async {
    return 'DELETE /admins/{id}';
  }
}
