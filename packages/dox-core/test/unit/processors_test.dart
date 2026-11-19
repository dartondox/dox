import 'package:dox_core/dox_core.dart';
import 'package:test/test.dart';

void main() {
  group('Processors', () {
    test('parseCpuList counts single ids and ranges', () {
      expect(Processors.parseCpuList('0-3,8,10-11'), 7);
      expect(Processors.parseCpuList('5'), 1);
    });

    test('parseCpuList gives null on bad input', () {
      expect(Processors.parseCpuList(''), isNull);
      expect(Processors.parseCpuList('a-b'), isNull);
      expect(Processors.parseCpuList('3-1'), isNull);
      expect(Processors.parseCpuList('1-2-3'), isNull);
    });

    test('parseCpusAllowed reads the status text', () {
      const String status =
          'Name:\tdart\nCpus_allowed:\tff\nCpus_allowed_list:\t0-1\nMems:\t0\n';
      expect(Processors.parseCpusAllowed(status), 2);
      expect(Processors.parseCpusAllowed('Name:\tdart\n'), isNull);
      expect(Processors.parseCpusAllowed(null), isNull);
    });

    test('parseCgroupV2 reads cpu.max', () {
      expect(Processors.parseCgroupV2('max 100000\n'), isNull);
      expect(Processors.parseCgroupV2('400000 100000\n'), 4);
      expect(Processors.parseCgroupV2('150000 100000'), 2);
      expect(Processors.parseCgroupV2('50000 100000'), 1);
      expect(Processors.parseCgroupV2('junk'), isNull);
      expect(Processors.parseCgroupV2(null), isNull);
    });

    test('parseCgroupV1 reads quota and period', () {
      expect(Processors.parseCgroupV1('-1\n', '100000\n'), isNull);
      expect(Processors.parseCgroupV1('200000\n', '100000\n'), 2);
      expect(Processors.parseCgroupV1('x', '100000'), isNull);
      expect(Processors.parseCgroupV1(null, '100000'), isNull);
    });

    test('available is at least 1 and is cached', () {
      expect(Processors.available, greaterThanOrEqualTo(1));
      expect(Processors.available, Processors.available);
    });
  });
}
