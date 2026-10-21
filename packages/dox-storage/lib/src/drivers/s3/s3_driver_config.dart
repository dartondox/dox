import '../../constants/storage_constants.dart';
import '../../types.dart';

/// Settings for [S3Driver].
///
/// Works with AWS S3 and S3-compatible services:
/// - Cloudflare R2: `endpoint: 'https://<account>.r2.cloudflarestorage.com'`,
///   `region: 'auto'`, `supportsAcl: false`.
/// - MinIO: `endpoint: 'http://localhost:9000'`, `forcePathStyle: true`.
/// - DigitalOcean Spaces: `endpoint: 'https://<region>.digitaloceanspaces.com'`.
/// - Google Cloud Storage (HMAC keys): `endpoint:
///   'https://storage.googleapis.com'`, `region: 'auto'`,
///   `supportsAcl: false`, `supportsBatchDelete: false`.
class S3DriverConfig {
  final String bucket;
  final String region;
  final String accessKeyId;
  final String secretAccessKey;

  /// Only for temporary credentials (STS).
  final String? sessionToken;

  /// Service URL without the bucket. Defaults to the AWS S3 endpoint
  /// for [region].
  final String? endpoint;

  /// Put the bucket in the path (`host/bucket/key`) instead of the host
  /// name (`bucket.host/key`). MinIO usually needs this.
  final bool forcePathStyle;

  /// Public URL base for `getUrl`, for example a CDN. When null, the
  /// bucket URL is used.
  final String? urlBase;

  /// Visibility for files written without one.
  final Visibility visibility;

  /// False for services without object ACLs (R2, GCS with uniform access,
  /// buckets with "ACLs disabled"). Then visibility calls do nothing and
  /// `getVisibility` returns [visibility].
  final bool supportsAcl;

  /// False for services without `DeleteObjects` (GCS). Then `deleteAll`
  /// deletes files one by one.
  final bool supportsBatchDelete;

  /// Part size for multipart upload in `putStream`. At least 5 MiB.
  final int multipartPartSize;

  const S3DriverConfig({
    required this.bucket,
    required this.region,
    required this.accessKeyId,
    required this.secretAccessKey,
    this.sessionToken,
    this.endpoint,
    this.forcePathStyle = false,
    this.urlBase,
    this.visibility = Visibility.private,
    this.supportsAcl = true,
    this.supportsBatchDelete = true,
    this.multipartPartSize = StorageConstants.defaultMultipartPartSize,
  });
}
