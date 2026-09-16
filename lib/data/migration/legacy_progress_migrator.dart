import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';


/// Small ports keep migration tests independent from Hive and sqflite. The
/// production adapters are the concrete repositories, while a failure
/// injector can implement these contracts without opening a database.
abstract interface class LegacyProgressSource {
  Future<Map<String, dynamic>> exportProgress();
}

abstract interface class MigrationTarget {
  Future<bool> hasCoreData();

  Future<Map<String, dynamic>?> latestMigrationReport();

  Future<void> recordMigrationRun({
    required String id,
    required int sourceSchema,
    required String sourceChecksum,
    required DateTime startedAt,
    DateTime? finishedAt,
    required String status,
    required Map<String, dynamic> report,
  });

  Future<void> importProgress(Map<String, dynamic> data);
}

class LegacyMigrationReport {
  final int sourceSchema;
  final String sourceChecksum;
  final String status;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String? backupPath;
  final int cardStates;
  final int testRuns;
  final int attempts;
  final int reviewEvents;
  final int exposureEvents;
  final int wordPreferences;
  final List<String> warnings;

  const LegacyMigrationReport({
    required this.sourceSchema,
    required this.sourceChecksum,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.backupPath,
    required this.cardStates,
    required this.testRuns,
    required this.attempts,
    required this.reviewEvents,
    required this.exposureEvents,
    this.wordPreferences = 0,
    this.warnings = const [],
  });

  Map<String, dynamic> toJson() => {
    'sourceSchema': sourceSchema,
    'sourceChecksum': sourceChecksum,
    'status': status,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt.toIso8601String(),
    'backupPath': backupPath,
    'cardStates': cardStates,
    'testRuns': testRuns,
    'attempts': attempts,
    'reviewEvents': reviewEvents,
    'exposureEvents': exposureEvents,
    'wordPreferences': wordPreferences,
    'warnings': warnings,
  };
}

/// Migrates the old Hive progress snapshot without making it the new writer.
///
/// The source remains intact. The target is populated only when it is empty;
/// failed imports are left out of the migration-complete path and can be
/// retried with the same checksum.
class LegacyProgressMigrator {
  final Directory? backupDirectory;

  const LegacyProgressMigrator({this.backupDirectory});

  /// Stable checksum used for migration idempotence. Export timestamps and
  /// map insertion order are intentionally excluded from the identity.
  static String checksumForSnapshot(Map<String, dynamic> snapshot) {
    final checksumSnapshot = Map<String, dynamic>.from(snapshot)
      ..remove('exportTime');
    final canonical = jsonEncode(_canonicalize(checksumSnapshot));
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  Future<LegacyMigrationReport> migrate({
    required LegacyProgressSource source,
    required MigrationTarget target,
  }) async {
    final startedAt = DateTime.now();
    final snapshot = await source.exportProgress();
    // exportTime is diagnostic metadata and must not make an unchanged
    // legacy store look like a new migration source on every launch.
    final canonicalSnapshot = Map<String, dynamic>.from(snapshot)
      ..remove('exportTime');
    final canonical = jsonEncode(_canonicalize(canonicalSnapshot));
    final checksum = checksumForSnapshot(snapshot);
    final sourceSchema = (snapshot['version'] as num?)?.toInt() ?? 0;
    final migrationId = 'legacy:$checksum';
    final previous = await target.latestMigrationReport();
    if (previous?['sourceChecksum'] == checksum &&
        previous?['status'] == 'completed') {
      return _reportFromSnapshot(
        snapshot,
        checksum: checksum,
        sourceSchema: sourceSchema,
        status: 'already-completed',
        startedAt: startedAt,
        backupPath: previous?['backupPath'] as String?,
        warnings: const [],
      );
    }

    if (await target.hasCoreData()) {
      final report = _reportFromSnapshot(
        snapshot,
        checksum: checksum,
        sourceSchema: sourceSchema,
        status: 'skipped-target-has-data',
        startedAt: startedAt,
        backupPath: null,
        warnings: const [
          'SQLite target already contains learning data; source was preserved.',
        ],
      );
      await target.recordMigrationRun(
        id: migrationId,
        sourceSchema: sourceSchema,
        sourceChecksum: checksum,
        startedAt: startedAt,
        finishedAt: report.finishedAt,
        status: report.status,
        report: report.toJson(),
      );
      return report;
    }

    String? backupPath;
    try {
      final directory =
          backupDirectory ?? await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      final file = File('${directory.path}/legacy-progress-$checksum.json');
      await file.writeAsString(canonical, flush: true);
      backupPath = file.path;
    } catch (_) {
      // A backup failure must be visible in the report, but it does not make
      // the source unusable; the source Hive boxes remain untouched.
    }

    await target.recordMigrationRun(
      id: migrationId,
      sourceSchema: sourceSchema,
      sourceChecksum: checksum,
      startedAt: startedAt,
      status: 'started',
      report: {'sourceChecksum': checksum, 'status': 'started'},
    );

    try {
      await target.importProgress(snapshot);
      final finishedAt = DateTime.now();
      final report = _reportFromSnapshot(
        snapshot,
        checksum: checksum,
        sourceSchema: sourceSchema,
        status: 'completed',
        startedAt: startedAt,
        backupPath: backupPath,
        warnings: backupPath == null
            ? const ['Could not write a local backup file.']
            : const [],
        finishedAt: finishedAt,
      );
      await target.recordMigrationRun(
        id: migrationId,
        sourceSchema: sourceSchema,
        sourceChecksum: checksum,
        startedAt: startedAt,
        finishedAt: finishedAt,
        status: report.status,
        report: report.toJson(),
      );
      return report;
    } catch (error) {
      final finishedAt = DateTime.now();
      final report = _reportFromSnapshot(
        snapshot,
        checksum: checksum,
        sourceSchema: sourceSchema,
        status: 'failed',
        startedAt: startedAt,
        backupPath: backupPath,
        warnings: ['Migration failed: $error'],
        finishedAt: finishedAt,
      );
      await target.recordMigrationRun(
        id: migrationId,
        sourceSchema: sourceSchema,
        sourceChecksum: checksum,
        startedAt: startedAt,
        finishedAt: finishedAt,
        status: report.status,
        report: report.toJson(),
      );
      rethrow;
    }
  }

  static dynamic _canonicalize(dynamic value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      return {
        for (final entry in entries)
          entry.key.toString(): _canonicalize(entry.value),
      };
    }
    if (value is List) {
      final canonical = value.map(_canonicalize).toList();
      canonical.sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
      return canonical;
    }
    return value;
  }

  LegacyMigrationReport _reportFromSnapshot(
    Map<String, dynamic> snapshot, {
    required String checksum,
    required int sourceSchema,
    required String status,
    required DateTime startedAt,
    required String? backupPath,
    required List<String> warnings,
    DateTime? finishedAt,
  }) {
    int length(String key) => (snapshot[key] as List?)?.length ?? 0;
    return LegacyMigrationReport(
      sourceSchema: sourceSchema,
      sourceChecksum: checksum,
      status: status,
      startedAt: startedAt,
      finishedAt: finishedAt ?? DateTime.now(),
      backupPath: backupPath,
      cardStates: length('cardStates'),
      testRuns: length('testRuns'),
      attempts: length('attempts'),
      reviewEvents: length('reviewEvents'),
      exposureEvents: length('exposureEvents'),
      wordPreferences: length('wordPreferences'),
      warnings: warnings,
    );
  }
}
