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
    return _cached ??= _detect();
  }

  static int _detect() {
    int count = Platform.numberOfProcessors;
    if (!Platform.isLinux) {
      return count;
    }
    count = _min(count, parseCpusAllowed(_read('/proc/self/status')));
    int? quota = parseCgroupV2(_read('/sys/fs/cgroup/cpu.max'));
    quota ??= parseCgroupV1(
      _read('/sys/fs/cgroup/cpu/cpu.cfs_quota_us'),
      _read('/sys/fs/cgroup/cpu/cpu.cfs_period_us'),
    );
    count = _min(count, quota);
    return count < 1 ? 1 : count;
  }

  static int _min(int current, int? other) {
    if (other == null || other < 1) {
      return current;
    }
    return other < current ? other : current;
  }

  static String? _read(String path) {
    try {
      return File(path).readAsStringSync();
    } on Object {
      return null;
    }
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

  /// Counts the CPUs in a list like `0-3,8,10-11`. Returns null on bad input.
  static int? parseCpuList(String list) {
    int total = 0;
    for (String part in list.split(',')) {
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
