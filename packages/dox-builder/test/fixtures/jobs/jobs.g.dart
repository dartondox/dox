// GENERATED CODE - DO NOT MODIFY BY HAND
// Made by dox_builder. Run `dart run build_runner build`.
// ignore_for_file: type=lint

import 'package:dox_queue/dox_queue.dart';

import 'test_jobs.dart' as i1;

/// Every `@Job()` class of the app.
/// Use it in `QueueConfig(jobs: jobRegistry)`.
const JobRegistry jobRegistry = JobRegistry(<JobCodec>[
  JobCodec('SendWelcomeEmail', i1.SendWelcomeEmail, _encode0, _decode0),
  JobCodec('all-types', i1.AllTypesJob, _encode1, _decode1),
  JobCodec('FlakyJob', i1.FlakyJob, _encode2, _decode2),
  JobCodec('SlowJob', i1.SlowJob, _encode3, _decode3),
]);

Map<String, Object?> _encode0(DoxJob job) {
  i1.SendWelcomeEmail value = job as i1.SendWelcomeEmail;
  return <String, Object?>{'userId': value.userId};
}

DoxJob _decode0(Map<String, Object?> data) {
  return i1.SendWelcomeEmail(userId: (data['userId'] as num).toInt());
}

Map<String, Object?> _encode1(DoxJob job) {
  i1.AllTypesJob value = job as i1.AllTypesJob;
  return <String, Object?>{
    'count': value.count,
    'price': value.price,
    'amount': value.amount,
    'title': value.title,
    'active': value.active,
    'at': value.at,
    'color': value.color,
    'note': value.note,
    'tags': value.tags,
    'scores': value.scores,
    'dates': value.dates,
    'nested': value.nested,
    'colors': value.colors,
    'extra': value.extra,
    'maybeAt': value.maybeAt,
    'maybeColor': value.maybeColor,
  };
}

DoxJob _decode1(Map<String, Object?> data) {
  return i1.AllTypesJob(
    (data['count'] as num).toInt(),
    (data['price'] as num).toDouble(),
    data['amount'] as num,
    data['title'] as String,
    data['active'] as bool,
    DateTime.parse(data['at'] as String),
    i1.Color.values.byName(data['color'] as String),
    note: data['note'] as String?,
    tags: <String>[
      for (Object? e1 in data['tags'] as List<Object?>) e1 as String,
    ],
    scores: <String, double>{
      for (MapEntry<String, Object?> e1
          in (data['scores'] as Map<String, Object?>).entries)
        e1.key: (e1.value as num).toDouble(),
    },
    dates: <DateTime?>[
      for (Object? e1 in data['dates'] as List<Object?>)
        (e1 == null ? null : DateTime.parse(e1 as String)),
    ],
    nested: <List<int>>[
      for (Object? e1 in data['nested'] as List<Object?>)
        <int>[for (Object? e2 in e1 as List<Object?>) (e2 as num).toInt()],
    ],
    colors: <String, i1.Color>{
      for (MapEntry<String, Object?> e1
          in (data['colors'] as Map<String, Object?>).entries)
        e1.key: i1.Color.values.byName(e1.value as String),
    },
    extra: (data['extra'] == null
        ? null
        : <String, dynamic>{
            for (MapEntry<String, Object?> e1
                in (data['extra'] as Map<String, Object?>).entries)
              e1.key: e1.value,
          }),
    maybeAt: (data['maybeAt'] == null
        ? null
        : DateTime.parse(data['maybeAt'] as String)),
    maybeColor: (data['maybeColor'] == null
        ? null
        : i1.Color.values.byName(data['maybeColor'] as String)),
  );
}

Map<String, Object?> _encode2(DoxJob job) {
  i1.FlakyJob value = job as i1.FlakyJob;
  return <String, Object?>{
    'key': value.key,
    'failTimes': value.failTimes,
    'maxTries': value.maxTries,
  };
}

DoxJob _decode2(Map<String, Object?> data) {
  return i1.FlakyJob(
    key: data['key'] as String,
    failTimes: (data['failTimes'] as num).toInt(),
    maxTries: (data['maxTries'] as num).toInt(),
  );
}

Map<String, Object?> _encode3(DoxJob job) {
  i1.SlowJob value = job as i1.SlowJob;
  return <String, Object?>{
    'key': value.key,
    'millis': value.millis,
    'timeoutMillis': value.timeoutMillis,
  };
}

DoxJob _decode3(Map<String, Object?> data) {
  return i1.SlowJob(
    key: data['key'] as String,
    millis: (data['millis'] as num).toInt(),
    timeoutMillis: (data['timeoutMillis'] as num?)?.toInt(),
  );
}
