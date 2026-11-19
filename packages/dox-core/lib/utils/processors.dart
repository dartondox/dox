import 'dart:io';

/// Finds how many CPUs this process may really use.
///
/// In a Linux container, `Platform.numberOfProcessors` shows all CPUs of the
/// host, even when the container is limited by cpuset or a CPU quota.
class Processors {
  Processors._();

  static int? _cached;

  /// CPUs this process may use. Never below 1.
  static int get available {
    return _cached ??= ProcessorsDetector.detect(
      reader: ProcFileReader(),
      numberOfProcessors: Platform.numberOfProcessors,
      isLinux: Platform.isLinux,
    );
  }
}

/// Does the work for [Processors]. Not exported from dox_core.
/// The parsers take file text, so tests can call them without real files.
class ProcessorsDetector {
  ProcessorsDetector._();

  /// Works out the usable CPUs from the files the [reader] gives.
  /// Tests pass a fake reader.
  static int detect({
    required ProcFileReader reader,
    required int numberOfProcessors,
    required bool isLinux,
  }) {
    int count = numberOfProcessors;
    if (!isLinux) {
      return count < 1 ? 1 : count;
    }
    count = _min(count, parseCpusAllowed(reader.read('/proc/self/status')));
    count = _min(count, _quota(reader));
    return count < 1 ? 1 : count;
  }

  static int _min(int current, int? other) {
    if (other == null || other < 1) {
      return current;
    }
    return other < current ? other : current;
  }

  /// The tightest CPU quota of the cgroup of this process and its parents.
  static int? _quota(ProcFileReader reader) {
    String? self = reader.read('/proc/self/cgroup');
    if (self == null) {
      return null;
    }
    int? v2;
    int? v1;
    for (String line in self.split('\n')) {
      line = line.trim();
      List<String> parts = line.split(':');
      if (parts.length < 3) {
        continue;
      }
      // The path may hold ':', so join the rest.
      String path = parts.sublist(2).join(':');
      if (parts[0] == '0' && parts[1].isEmpty) {
        v2 = _walk(reader, '/sys/fs/cgroup', path, v2: true);
      } else if (parts[1].split(',').contains('cpu')) {
        v1 = _walk(reader, '/sys/fs/cgroup/cpu', path, v2: false);
      }
    }
    return v2 ?? v1;
  }

  static int? _readV2(ProcFileReader reader, String dir) {
    return parseCgroupV2(reader.read('$dir/cpu.max'));
  }

  static int? _readV1(ProcFileReader reader, String dir) {
    return parseCgroupV1(
      reader.read('$dir/cpu.cfs_quota_us'),
      reader.read('$dir/cpu.cfs_period_us'),
    );
  }

  /// Reads [root] plus [path], then each parent folder, then [root].
  /// Returns the smallest quota found, or null.
  static int? _walk(
    ProcFileReader reader,
    String root,
    String path, {
    required bool v2,
  }) {
    List<String> names = <String>[];
    for (String name in path.split('/')) {
      if (name.isNotEmpty) {
        names.add(name);
      }
    }
    if (names.contains('..') || names.contains('.')) {
      names.clear();
    }
    int? best;
    // The loop runs once per folder level.
    for (int i = names.length; i >= 0; i--) {
      String dir = <String>[root, ...names.take(i)].join('/');
      int? quota = v2 ? _readV2(reader, dir) : _readV1(reader, dir);
      if (quota != null && (best == null || quota < best)) {
        best = quota;
      }
    }
    return best;
  }

  /// Reads the `Cpus_allowed_list:` line of `/proc/self/status`.
  /// The list looks like `0-3,8,10-11`. Returns null on bad input.
  static int? parseCpusAllowed(String? status) {
    if (status == null) {
      return null;
    }
    RegExpMatch? line = RegExp(
      r'^Cpus_allowed_list:\s*(.+)$',
      multiLine: true,
    ).firstMatch(status);
    if (line == null) {
      return null;
    }
    return parseCpuList(line.group(1)!.trim());
  }

  /// Counts the CPUs in a list like `0-3,8,10-11`. Empty parts are skipped.
  /// Returns null on bad input.
  static int? parseCpuList(String list) {
    int total = 0;
    for (String part in list.split(',')) {
      if (part.trim().isEmpty) {
        continue;
      }
      List<String> range = part.trim().split('-');
      int? from = int.tryParse(range.first);
      int? to = range.length == 2 ? int.tryParse(range.last) : from;
      if (range.length > 2 || from == null || to == null || to < from) {
        return null;
      }
      total += to - from + 1;
    }
    return total < 1 ? null : total;
  }

  /// Reads cgroup v2 `cpu.max`: `max 100000` (no limit) or `400000 100000`.
  /// Returns null when there is no limit or the text is bad.
  static int? parseCgroupV2(String? text) {
    if (text == null) {
      return null;
    }
    List<String> parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length != 2) {
      return null;
    }
    return _ceilQuota(int.tryParse(parts[0]), int.tryParse(parts[1]));
  }

  /// Reads cgroup v1 `cpu.cfs_quota_us` and `cpu.cfs_period_us`.
  /// A quota of -1 means no limit. Returns null on no limit or bad text.
  static int? parseCgroupV1(String? quota, String? period) {
    if (quota == null || period == null) {
      return null;
    }
    return _ceilQuota(int.tryParse(quota.trim()), int.tryParse(period.trim()));
  }

  static int? _ceilQuota(int? quota, int? period) {
    if (quota == null || period == null || quota <= 0 || period <= 0) {
      return null;
    }
    return (quota + period - 1) ~/ period;
  }
}

/// Reads a file as text. Gives null when the file can not be read.
/// Tests pass a fake that extends this class.
class ProcFileReader {
  String? read(String path) {
    try {
      return File(path).readAsStringSync();
    } on Object {
      return null;
    }
  }
}
