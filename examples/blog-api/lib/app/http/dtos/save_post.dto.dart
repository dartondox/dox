import 'package:dox_core/dox_core.dart';

part 'save_post.dto.g.dart';

/// Typed, checked input. Run `dox build_runner:build` after a change.
@Dto()
class SavePost {
  @Trim()
  @Length(min: 3, max: 100)
  final String title;

  @Trim()
  @MinLength(10)
  final String body;

  const SavePost({required this.title, required this.body});

  static const DtoSchema<SavePost> schema = $SavePostDto;
}
