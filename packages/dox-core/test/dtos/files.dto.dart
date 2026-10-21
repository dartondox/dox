import 'package:dox_core/dox_core.dart';

part 'files.dto.g.dart';

@Dto()
class UploadAvatar {
  @Image()
  @MaxSize('1KB')
  final RequestFile avatar;

  @MaxItems(2)
  @Mimes(<String>['pdf', 'docx'])
  final List<RequestFile> documents;

  final String? title;

  const UploadAvatar({
    required this.avatar,
    this.documents = const <RequestFile>[],
    this.title,
  });

  static const DtoSchema<UploadAvatar> schema = $UploadAvatarDto;
}
