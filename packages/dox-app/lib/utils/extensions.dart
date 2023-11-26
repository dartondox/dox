extension Slugify on String {
  String slugify({String separator = '-'}) {
    String input = this;
    // Remove leading and trailing whitespaces
    String slug = input.trim();

    // Convert to lowercase
    slug = slug.toLowerCase();

    // Replace spaces and underscores with dashes
    slug = slug.replaceAll(RegExp(r'[\s_]+'), separator);

    // Remove special characters
    slug = slug.replaceAll(RegExp(r'[^a-z0-9\u0080-\uFFFF-]'), '');

    // Remove consecutive dashes
    slug = slug.replaceAll(RegExp(r'-+'), separator);

    // Remove leading and trailing dashes
    slug = slug.replaceAll(RegExp(r'^-|-$'), '');

    return slug;
  }
}
