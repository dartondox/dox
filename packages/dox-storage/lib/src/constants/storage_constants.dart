/// Global constants for dox_storage.
class StorageConstants {
  StorageConstants._();

  /// How long a signed URL stays valid when no time is given.
  static const Duration defaultSignedUrlExpiry = Duration(minutes: 30);

  /// S3 does not accept presigned URLs that live longer than 7 days.
  static const Duration maxS3SignedUrlExpiry = Duration(days: 7);

  /// Part size for S3 multipart upload. S3 needs at least 5 MiB per part.
  static const int defaultMultipartPartSize = 8 * 1024 * 1024;

  /// Smallest part size S3 accepts (all parts except the last one).
  static const int minMultipartPartSize = 5 * 1024 * 1024;

  /// S3 allows at most 10,000 parts. With 8 MiB parts that is about 78 GiB.
  static const int maxMultipartParts = 10000;

  /// S3 DeleteObjects takes at most 1000 keys per request.
  static const int s3DeleteBatchSize = 1000;

  /// SigV4 algorithm name.
  static const String sigV4Algorithm = 'AWS4-HMAC-SHA256';

  /// Payload hash value for presigned URLs.
  static const String unsignedPayload = 'UNSIGNED-PAYLOAD';

  /// SHA-256 of an empty body.
  static const String emptyPayloadHash =
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

  /// Group URI that S3 uses for public read grants.
  static const String s3AllUsersGroup =
      'http://acs.amazonaws.com/groups/global/AllUsers';

  /// Query parameter names for local signed URLs.
  static const String localExpiresParam = 'expires';
  static const String localSignatureParam = 'signature';

  /// Content type used when nothing better is known.
  static const String defaultContentType = 'application/octet-stream';
}
