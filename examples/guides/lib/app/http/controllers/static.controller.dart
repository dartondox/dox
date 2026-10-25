import 'dart:io';

import 'package:dox_core/dox_core.dart';
import 'package:dox_storage/dox_storage.dart';

@Inject()
class StaticController {
  /// GET /assets/{path*}
  /// Built files have a hash in the name, so the browser may keep them
  /// for one year. The `public` disk rejects `..` in the path.
  Future<DoxResponse> asset(String path) async {
    StreamFile file = await Storage().disk('public').stream(path);
    return response(file).cache(const Duration(days: 365));
  }

  /// GET / and GET /{path*}
  /// Every other URL gets index.html, so the router of the SPA can
  /// handle it. Never cache it, so a new deploy shows at once.
  /// An unknown API URL stays a 404, it does not get the page.
  DoxResponse index(DoxRequest req) {
    if (req.uri.path.startsWith('/api/')) {
      throw NotFoundHttpException();
    }
    return response(File('public/index.html')).cache(Duration.zero);
  }
}
