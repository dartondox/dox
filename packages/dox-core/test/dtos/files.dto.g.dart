// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'files.dto.dart';

// **************************************************************************
// DoxDtoGenerator
// **************************************************************************

// ignore_for_file: type=lint

/// The checks, the converter and the JSON Schema of [UploadAvatar].
const DtoSchema<UploadAvatar> $UploadAvatarDto = _$UploadAvatarDto();

class _$UploadAvatarDto extends DtoSchema<UploadAvatar>
    implements JsonObjectWriter {
  const _$UploadAvatarDto();

  static const Map<String, String> _messages = <String, String>{};

  static final JsonRun _avatarKey = JsonRun('{"avatar":');
  static final JsonRun _documentsKey = JsonRun(',"documents":');
  static final JsonRun _titleKey = JsonRun(',"title":');
  static final JsonRun _end = JsonRun('}');

  @override
  Type get type => UploadAvatar;

  @override
  String get name => 'UploadAvatar';

  @override
  bool get usesRequiredWhen => false;

  @override
  UploadAvatar? convert(Object? input, DtoState state, List<Object> path) {
    if (input is! Map) {
      state.notObject(input, path, _messages);
      return null;
    }
    int issuesBefore = state.issues.length;
    // avatar: RequestFile
    Object? avatar = state.file(
      state.read(input, 'avatar'),
      path,
      'avatar',
      _messages,
    );
    if (avatar == null || avatar is Undefined)
      state.required(path, 'avatar', _messages);
    // documents: List<RequestFile>
    Object? documents = state.list(
      state.read(input, 'documents'),
      path,
      'documents',
      _messages,
    );
    if (documents is List) {
      int b0 = state.issues.length;
      List<Object> q0 = <Object>[...path, 'documents'];
      List<RequestFile> o0 = <RequestFile>[];
      for (int i0 = 0; i0 < documents.length; i0++) {
        Object? x0 = state.file(documents[i0], q0, i0, _messages);
        if (x0 == null || x0 is Undefined) {
          state.required(q0, i0, _messages);
        } else if (x0 is! Invalid) {
          o0.add(x0 as RequestFile);
        }
      }
      documents = state.issues.length != b0 ? invalid : o0;
    }
    if (documents == null) state.required(path, 'documents', _messages);
    // title: String?
    Object? title = state.string(
      state.read(input, 'title'),
      path,
      'title',
      _messages,
    );
    if (state.issues.length != issuesBefore && !state.allErrors) return null;
    if (avatar is RequestFile) {
      if (!(FileTypes.matches(avatar, SchemaConstants.imageExtensions))) {
        state.fail(
          path,
          'avatar',
          IssueCodes.image,
          DefaultMessages.image,
          avatar,
          messages: _messages,
        );
      } else if (!(avatar.length <= 1024)) {
        state.fail(
          path,
          'avatar',
          IssueCodes.maxSize,
          DefaultMessages.maxSize,
          avatar,
          params: const <String, Object?>{'max': '1KB'},
          messages: _messages,
        );
      }
    }
    if (documents is List<RequestFile>) {
      if (!(documents.length <= 2)) {
        state.fail(
          path,
          'documents',
          IssueCodes.maxItems,
          DefaultMessages.maxItems,
          documents,
          params: const <String, Object?>{'max': 2},
          messages: _messages,
        );
      } else {
        List<Object> q = <Object>[...path, 'documents'];
        for (int i = 0; i < documents.length; i++) {
          RequestFile v = documents[i];
          if (!(FileTypes.matches(v, const <String>['pdf', 'docx']))) {
            state.fail(
              q,
              i,
              IssueCodes.mimes,
              DefaultMessages.mimes,
              v,
              params: const <String, Object?>{'types': 'pdf, docx'},
              messages: _messages,
            );
          }
        }
      }
    }
    if (state.issues.length != issuesBefore) return null;
    return UploadAvatar(
      avatar: avatar as RequestFile,
      documents: documents is Undefined
          ? const <RequestFile>[]
          : documents as List<RequestFile>,
      title: title is Undefined ? null : title as String?,
    );
  }

  @override
  UploadAvatar fromMap(Map<String, dynamic> map) {
    return UploadAvatar(
      avatar: map['avatar'] as RequestFile,
      documents: map.containsKey('documents')
          ? <RequestFile>[
              for (Object? x0 in map['documents'] as List<dynamic>)
                x0 as RequestFile,
            ]
          : const <RequestFile>[],
      title: map['title'] == null ? null : (map['title'] as String),
    );
  }

  @override
  Map<String, dynamic> toMap(UploadAvatar dto) {
    return <String, dynamic>{
      'avatar': dto.avatar,
      'documents': dto.documents,
      'title': dto.title,
    };
  }

  @override
  void writeObject(Object object, JsonWriter writer) =>
      $writeUploadAvatar(object as UploadAvatar, writer);

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

/// Writes the JSON of [UploadAvatar], as `toMap()` gives it.
void $writeUploadAvatar(UploadAvatar dto, JsonWriter writer) {
  writer.run(_$UploadAvatarDto._avatarKey);
  writer.value(dto.avatar);
  writer.run(_$UploadAvatarDto._documentsKey);
  writer.value(dto.documents);
  writer.run(_$UploadAvatarDto._titleKey);
  writer.string(dto.title);
  writer.run(_$UploadAvatarDto._end);
}
