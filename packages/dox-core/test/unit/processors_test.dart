import 'package:dox_core/dox_core.dart';
import 'package:dox_core/utils/processors.dart' as impl;
import 'package:test/test.dart';

class FakeReader extends impl.ProcFileReader {
  final Map<String, String> files;
  FakeReader(this.files);

  @override
  String? read(String path) {
    return files[path];
  }
}

int detect(Map<String, String> files, {int cpus = 8}) {
  return impl.Processors.detect(
    reader: FakeReader(files),
    numberOfProcessors: cpus,
    isLinux: true,
  );
}

String status(String list) {
  return 'Name:\tdart\nCpus_allowed:\tff\nCpus_allowed_list:\t$list\nMems:\t0\n';
}

void main() {
  group('parsers', () {
    test('parseCpuList counts ids and ranges', () {
      expect(impl.Processors.parseCpuList('0-3,8,10-11'), 7);
      expect(impl.Processors.parseCpuList('5'), 1);
      expect(impl.Processors.parseCpuList('0-1,'), 2);
    });

    test('parseCpuList gives null on bad input', () {
      expect(impl.Processors.parseCpuList(''), isNull);
      expect(impl.Processors.parseCpuList('a-b'), isNull);
      expect(impl.Processors.parseCpuList('3-1'), isNull);
      expect(impl.Processors.parseCpuList('1-2-3'), isNull);
    });

    test('parseCpusAllowed handles trailing space and CRLF', () {
      expect(impl.Processors.parseCpusAllowed(status('0-1')), 2);
      expect(impl.Processors.parseCpusAllowed(status('0-1 ')), 2);
      expect(
        impl.Processors.parseCpusAllowed('Cpus_allowed_list:\t0-3\r\nMems:\t0'),
        4,
      );
      expect(impl.Processors.parseCpusAllowed('Name:\tdart\n'), isNull);
      expect(impl.Processors.parseCpusAllowed(null), isNull);
    });

    test('parseCgroupV2 reads cpu.max', () {
      expect(impl.Processors.parseCgroupV2('max 100000\n'), isNull);
      expect(impl.Processors.parseCgroupV2('400000 100000\n'), 4);
      expect(impl.Processors.parseCgroupV2('150000 100000'), 2);
      expect(impl.Processors.parseCgroupV2('50000 100000'), 1);
      expect(impl.Processors.parseCgroupV2('100000 0'), isNull);
      expect(impl.Processors.parseCgroupV2('100000 100000 5'), isNull);
      expect(impl.Processors.parseCgroupV2('junk'), isNull);
      expect(impl.Processors.parseCgroupV2(null), isNull);
    });

    test('parseCgroupV1 reads quota and period', () {
      expect(impl.Processors.parseCgroupV1('-1\n', '100000\n'), isNull);
      expect(impl.Processors.parseCgroupV1('200000\n', '100000\n'), 2);
      expect(impl.Processors.parseCgroupV1('x', '100000'), isNull);
      expect(impl.Processors.parseCgroupV1(null, '100000'), isNull);
    });
  });

  group('detect', () {
    test('not Linux uses the CPU count', () {
      expect(
        impl.Processors.detect(
          reader: FakeReader(<String, String>{}),
          numberOfProcessors: 6,
          isLinux: false,
        ),
        6,
      );
    });

    test('no files gives the CPU count', () {
      expect(detect(<String, String>{}), 8);
    });

    test('cpuset only', () {
      expect(detect(<String, String>{'/proc/self/status': status('0-1')}), 2);
    });

    test('min of cpuset and quota', () {
      expect(
        detect(<String, String>{
          '/proc/self/status': status('0-5'),
          '/proc/self/cgroup': '0::/\n',
          '/sys/fs/cgroup/cpu.max': '300000 100000',
        }),
        3,
      );
      expect(
        detect(<String, String>{
          '/proc/self/status': status('0-1'),
          '/proc/self/cgroup': '0::/\n',
          '/sys/fs/cgroup/cpu.max': '300000 100000',
        }),
        2,
      );
    });

    test('never below 1', () {
      expect(
        detect(<String, String>{
          '/proc/self/cgroup': '0::/\n',
          '/sys/fs/cgroup/cpu.max': '10000 100000',
        }),
        1,
      );
      expect(detect(<String, String>{}, cpus: 0), 1);
    });

    test('v2 nested path with a tighter parent', () {
      expect(
        detect(<String, String>{
          '/proc/self/cgroup': '0::/a/b\n',
          '/sys/fs/cgroup/a/b/cpu.max': 'max 100000',
          '/sys/fs/cgroup/a/cpu.max': '200000 100000',
          '/sys/fs/cgroup/cpu.max': '600000 100000',
        }),
        2,
      );
    });

    test('v2 nested path with a tighter child', () {
      expect(
        detect(<String, String>{
          '/proc/self/cgroup': '0::/a/b\n',
          '/sys/fs/cgroup/a/b/cpu.max': '100000 100000',
          '/sys/fs/cgroup/a/cpu.max': '400000 100000',
        }),
        1,
      );
    });

    test('v2 missing falls back to v1', () {
      expect(
        detect(<String, String>{
          '/proc/self/cgroup': '4:cpu,cpuacct:/docker/x\n1:name=systemd:/\n',
          '/sys/fs/cgroup/cpu/docker/x/cpu.cfs_quota_us': '-1',
          '/sys/fs/cgroup/cpu/docker/x/cpu.cfs_period_us': '100000',
          '/sys/fs/cgroup/cpu/cpu.cfs_quota_us': '200000',
          '/sys/fs/cgroup/cpu/cpu.cfs_period_us': '100000',
        }),
        2,
      );
    });

    test('bad cgroup text is ignored', () {
      expect(
        detect(<String, String>{
          '/proc/self/cgroup': 'junk\n0::/../x\n',
          '/sys/fs/cgroup/cpu.max': '200000 100000',
        }),
        2,
      );
    });
  });

  test('Processors.available is at least 1 and cached', () {
    expect(Processors.available, greaterThanOrEqualTo(1));
    expect(Processors.available, Processors.available);
  });
}
