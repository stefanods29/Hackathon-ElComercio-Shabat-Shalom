import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;

/// When the app last asked the CDN about a zone. It only spaces out the checks: losing it costs
/// one more check, never the copy.
class EmergencyCheck {
  const EmergencyCheck({required this.zoneId, required this.checkedAt});

  final String zoneId;
  final DateTime checkedAt;
}

/// Last valid copy of the emergency directory. It lives outside the account database because it
/// is public and must open without a session: signing out does not delete it.
abstract interface class EmergencyDirectoryStore {
  /// The district file exactly as it was downloaded, or null when there is none.
  Future<Uint8List?> readDirectory();

  /// Replaces the copy atomically: a reader sees the previous file or the new one, never half.
  Future<void> saveDirectory(Uint8List bytes);

  Future<void> deleteDirectory();

  Future<EmergencyCheck?> readLastCheck();

  Future<void> saveLastCheck(EmergencyCheck check);

  /// Forgets the zone of the last check (account deletion). The public copy stays.
  Future<void> deleteLastCheck();
}

/// Files `directorio.json` and `revision.json` in [directory], written to a temporary file and
/// renamed over the previous one.
class FileEmergencyDirectoryStore implements EmergencyDirectoryStore {
  FileEmergencyDirectoryStore(this.directory);

  /// For example `<application support>/emergencia`.
  final String directory;

  File get _directoryFile => File(path.join(directory, 'directorio.json'));
  File get _checkFile => File(path.join(directory, 'revision.json'));

  @override
  Future<Uint8List?> readDirectory() async {
    try {
      final bytes = await _directoryFile.readAsBytes();
      return bytes;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> saveDirectory(Uint8List bytes) => _replace(_directoryFile, bytes);

  @override
  Future<void> deleteDirectory() => _delete(_directoryFile);

  @override
  Future<EmergencyCheck?> readLastCheck() async {
    try {
      final json = jsonDecode(await _checkFile.readAsString());
      if (json is! Map<String, Object?>) return null;
      final zoneId = json['zonaId'];
      final checkedAt = json['revisadoEn'];
      if (zoneId is! String || checkedAt is! String) return null;
      final parsed = DateTime.tryParse(checkedAt);
      return parsed == null ? null : EmergencyCheck(zoneId: zoneId, checkedAt: parsed);
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> saveLastCheck(EmergencyCheck check) => _replace(
    _checkFile,
    utf8.encode(
      jsonEncode({'zonaId': check.zoneId, 'revisadoEn': check.checkedAt.toUtc().toIso8601String()}),
    ),
  );

  @override
  Future<void> deleteLastCheck() => _delete(_checkFile);

  Future<void> _replace(File target, List<int> bytes) async {
    await Directory(directory).create(recursive: true);
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(target.path);
  }

  Future<void> _delete(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}

/// Test double and default copy of the app without a session on disk.
class InMemoryEmergencyDirectoryStore implements EmergencyDirectoryStore {
  InMemoryEmergencyDirectoryStore({this._directory, this._lastCheck});

  Uint8List? _directory;
  EmergencyCheck? _lastCheck;

  @override
  Future<Uint8List?> readDirectory() async => _directory;

  @override
  Future<void> saveDirectory(Uint8List bytes) async {
    _directory = Uint8List.fromList(bytes);
  }

  @override
  Future<void> deleteDirectory() async {
    _directory = null;
  }

  @override
  Future<EmergencyCheck?> readLastCheck() async => _lastCheck;

  @override
  Future<void> saveLastCheck(EmergencyCheck check) async {
    _lastCheck = check;
  }

  @override
  Future<void> deleteLastCheck() async {
    _lastCheck = null;
  }
}
