// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'files.dto.dart';

// **************************************************************************
// DoxDtoGenerator
// **************************************************************************

// ignore_for_file: type=lint

/// The checks, the converter and the JSON Schema of [UploadAvatar].
const DtoSchema<UploadAvatar> $UploadAvatarDto = _$UploadAvatarDto();

class _$UploadAvatarDto extends DtoSchema<UploadAvatar> {
  const _$UploadAvatarDto();

  static const Map<String, String> _m = <String, String>{};

  @override
  Type get type => UploadAvatar;

  @override
  String get name => 'UploadAvatar';

  @override
  UploadAvatar? convert(Object? input, DtoState s, List<Object> p) {
    if (input is! Map) {
      s.notObject(input, p, _m);
      return null;
    }
    int e = s.issues.length;
    // avatar: RequestFile
    Object? c0;
    c0 = s.file(s.read(input, 'avatar'), p, 'avatar', _m);
    if (c0 == null || c0 is Undefined) s.required(p, 'avatar', _m);
    // documents: List<RequestFile>
    Object? c1;
    c1 = s.list(s.read(input, 'documents'), p, 'documents', _m);
    if (c1 is List) {
      List<Object> q0 = <Object>[...p, 'documents'];
      List<RequestFile> o0 = <RequestFile>[];
      for (int i0 = 0; i0 < c1.length; i0++) {
        Object? x0;
        x0 = s.file(c1[i0], q0, i0, _m);
        if (x0 == null || x0 is Undefined) {
          s.required(q0, i0, _m);
        } else if (x0 is! Invalid) {
          o0.add(x0 as RequestFile);
        }
      }
      c1 = o0;
    }
    if (c1 == null) s.required(p, 'documents', _m);
    // title: String?
    Object? c2;
    c2 = s.string(s.read(input, 'title'), p, 'title', _m);
    if (s.issues.length != e) return null;
    if (c0 is RequestFile) {
      if (!(FileTypes.matches(c0, SchemaConstants.imageExtensions))) {
        s.fail(
          p,
          'avatar',
          IssueCodes.image,
          DefaultMessages.image,
          c0,
          messages: _m,
        );
      } else if (!(c0.length <= 1024)) {
        s.fail(
          p,
          'avatar',
          IssueCodes.maxSize,
          DefaultMessages.maxSize,
          c0,
          params: const <String, Object?>{'max': '1KB'},
          messages: _m,
        );
      }
    }
    if (c1 is List<RequestFile>) {
      if (!(c1.length <= 2)) {
        s.fail(
          p,
          'documents',
          IssueCodes.maxItems,
          DefaultMessages.maxItems,
          c1,
          params: const <String, Object?>{'max': 2},
          messages: _m,
        );
      } else {
        List<Object> q = <Object>[...p, 'documents'];
        for (int i = 0; i < c1.length; i++) {
          RequestFile v = c1[i];
          if (!(FileTypes.matches(v, const <String>['pdf', 'docx']))) {
            s.fail(
              q,
              i,
              IssueCodes.mimes,
              DefaultMessages.mimes,
              v,
              params: const <String, Object?>{'types': 'pdf, docx'},
              messages: _m,
            );
          }
        }
      }
    }
    if (s.issues.length != e) return null;
    return UploadAvatar(
      avatar: c0 as RequestFile,
      documents: c1 is Undefined
          ? const <RequestFile>[]
          : c1 as List<RequestFile>,
      title: c2 is Undefined ? null : c2 as String?,
    );
  }

  @override
  UploadAvatar fromMap(Map<String, dynamic> m) {
    return UploadAvatar(
      avatar: m['avatar'] as RequestFile,
      documents: m.containsKey('documents')
          ? <RequestFile>[
              for (Object? x0 in m['documents'] as List<dynamic>)
                x0 as RequestFile,
            ]
          : const <RequestFile>[],
      title: m['title'] == null ? null : (m['title'] as String),
    );
  }

  @override
  Map<String, dynamic> toMap(UploadAvatar o) {
    RequestFile f0 = o.avatar;
    List<RequestFile> f1 = o.documents;
    String? f2 = o.title;
    return <String, dynamic>{'avatar': f0, 'documents': f1, 'title': f2};
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return <String, dynamic>{
      'type': 'object',
      'title': 'UploadAvatar',
      'properties': <String, dynamic>{
        'avatar': <String, dynamic>{
          'type': 'string',
          'format': 'binary',
          'contentMediaType': 'image/*',
          'maxLength': 1024,
        },
        'documents': <String, dynamic>{
          'type': 'array',
          'items': <String, dynamic>{
            'type': 'string',
            'format': 'binary',
            'contentMediaType': 'application/pdf, application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          },
          'maxItems': 2,
          'default': <dynamic>[],
        },
        'title': <String, dynamic>{
          'type': <dynamic>['string', 'null'],
        },
      },
      'required': <dynamic>['avatar'],
    };
  }
}
