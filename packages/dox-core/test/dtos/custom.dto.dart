import 'package:dox_core/dox_core.dart';

part 'custom.dto.g.dart';

class Slug extends Rule<String> {
  const Slug({super.message});

  @override
  String get name {
    return 'slug';
  }

  @override
  String get defaultMessage {
    return 'The {field} must be a slug';
  }

  @override
  bool check(String value, RuleContext context) {
    return _pattern.hasMatch(value);
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{'pattern': r'^[a-z0-9]+(-[a-z0-9]+)*$'};
  }

  static final RegExp _pattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
}

class MinValue extends Rule<int> {
  const MinValue(this.min, {super.message});

  final int min;

  @override
  String get name {
    return 'min_value';
  }

  @override
  String get defaultMessage {
    return 'The {field} must be at least {min}';
  }

  @override
  Map<String, Object?> get params {
    return <String, Object?>{'min': min};
  }

  @override
  bool check(int value, RuleContext context) {
    return value >= min;
  }
}

/// fails for the text `taken`, after a short wait
class NotTaken extends AsyncRule<String> {
  const NotTaken();

  @override
  String get name {
    return 'not_taken';
  }

  @override
  String get defaultMessage {
    return 'The {field} is taken';
  }

  @override
  Future<bool> checkAsync(String value, RuleContext context) async {
    await Future<void>.delayed(Duration.zero);
    return value != 'taken';
  }
}

@Dto()
class CreatePost {
  @Slug()
  final String slug;

  @MinValue(5)
  final List<int> scores;

  @NotTaken()
  final String? handle;

  @NotTaken()
  final List<String> handles;

  const CreatePost({
    required this.slug,
    this.scores = const <int>[],
    this.handle,
    this.handles = const <String>[],
  });

  static const DtoSchema<CreatePost> schema = $CreatePostDto;
}
