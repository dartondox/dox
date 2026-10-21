import 'disk.dart';
import 'driver_contract.dart';
import 'drivers/memory_driver.dart';
import 'exceptions.dart';

/// Holds named disks and picks the right one.
///
/// ```dart
/// DriveManager drive = DriveManager(
///   defaultDisk: 'local',
///   disks: <String, DriverContract>{
///     'local': LocalDriver(LocalDriverConfig(root: 'storage')),
///     's3': S3Driver(S3DriverConfig(...)),
///   },
/// );
/// await drive.use('s3').put('a.txt', 'hello');
/// ```
class DriveManager {
  /// Name of the disk that [use] returns when no name is given.
  final String defaultDisk;

  final Map<String, Disk> _disks = <String, Disk>{};
  final Map<String, Disk> _fakes = <String, Disk>{};

  DriveManager({
    required this.defaultDisk,
    Map<String, DriverContract> disks = const <String, DriverContract>{},
  }) {
    disks.forEach(register);
  }

  /// Add or replace a disk. Use this for your own drivers too.
  void register(String name, DriverContract driver) {
    _disks[name] = Disk(driver);
  }

  /// Names of all registered disks.
  Iterable<String> get diskNames {
    return _disks.keys;
  }

  /// Get a disk by name. Without a name, returns the default disk.
  Disk use([String? name]) {
    String diskName = name ?? defaultDisk;
    Disk? disk = _fakes[diskName] ?? _disks[diskName];
    if (disk == null) {
      throw UnsupportedOperationException(
        diskName,
        'Disk "$diskName" is not registered',
      );
    }
    return disk;
  }

  /// Swap a disk with an in-memory fake until [restore] is called.
  /// Returns the fake disk so a test can check what was written.
  Disk fake([String? name]) {
    String diskName = name ?? defaultDisk;
    Disk disk = Disk(MemoryDriver());
    _fakes[diskName] = disk;
    return disk;
  }

  /// Put the real disk back after [fake].
  void restore([String? name]) {
    _fakes.remove(name ?? defaultDisk);
  }

  /// Remove all fakes.
  void restoreAll() {
    _fakes.clear();
  }
}
