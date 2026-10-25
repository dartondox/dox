import 'package:dox_core/dox_core.dart';
import 'package:dox_storage/dox_storage.dart';
import 'package:my_app/app/dtos/upload_image/upload_image.dto.dart';

@Inject()
class UploadController {
  /// POST /api/upload (multipart/form-data, field `image`)
  Future<Map<String, String>> store(UploadImage body) async {
    // saves the file as /images/<uuid>.<ext> on the default disk
    String path = await Storage().putRequestFile('images', body.image);
    String url = await Storage().url(path);
    return <String, String>{'path': path, 'url': url};
  }
}
