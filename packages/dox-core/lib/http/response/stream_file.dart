import 'dart:io';

/// A file to send as a stream, from a controller.
/// The body is not loaded into memory.
class StreamFile {
  final ContentType contentType;
  final Stream<List<int>> stream;

  /// size in bytes when known, sent as Content-Length
  final int? length;
  const StreamFile(this.contentType, this.stream, {this.length});
}

class DownloadableFile {
  final ContentType contentType;
  final Stream<List<int>> stream;

  /// size in bytes when known, sent as Content-Length
  final int? length;

  String contentDisposition = '';
  DownloadableFile(
    this.contentType,
    this.stream,
    String filename, {
    this.length,
  }) {
    contentDisposition = 'attachment; filename="$filename"';
  }
}
