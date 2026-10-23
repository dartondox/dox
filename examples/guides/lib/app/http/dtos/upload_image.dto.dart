import 'package:dox_core/dox_core.dart';

part 'upload_image.dto.g.dart';

@Dto()
class UploadImage {
  /// jpg, jpeg, png, gif, webp or bmp. Dox reads the first bytes of the
  /// file to find the real type. The file name is not trusted.
  @Image()
  @MaxSize('5MB')
  final RequestFile image;

  const UploadImage({required this.image});

  static const DtoSchema<UploadImage> schema = $UploadImageDto;
}
