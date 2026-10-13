import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:vocab_flash_test/data/sqlite/sqlite_progress_repository.dart';
import 'package:vocab_flash_test/data/word_repository.dart';
import 'package:vocab_flash_test/models/word.dart';

class _Words implements WordRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class _Database implements Database {
  String? fingerprint;
  int batches = 0;
  int inserts = 0;
  bool fail = false;
  @override
  Future<T> transaction<T>(Future<T> Function(Transaction) action, {bool? exclusive}) async {
    final old = fingerprint;
    try { return await action(_Transaction(this)); }
    catch (_) { fingerprint = old; rethrow; }
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class _Transaction implements Transaction {
  final _Database db;
  _Transaction(this.db);
  @override
  Future<List<Map<String, Object?>>> query(String table, {bool? distinct, List<String>? columns, String? where, List<Object?>? whereArgs, String? groupBy, String? having, String? orderBy, int? limit, int? offset}) async => db.fingerprint == null ? [] : [{'value': db.fingerprint}];
  @override
  Batch batch() => _Batch(db);
  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    if (table == 'meta') db.fingerprint = null;
    return 0;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
class _Batch implements Batch {
  final _Database db;
  final rows = <(String, Map<String, Object?>)>[];
  _Batch(this.db);
  @override
  void insert(String table, Map<String, Object?> values, {String? nullColumnHack, ConflictAlgorithm? conflictAlgorithm}) => rows.add((table, values));
  @override
  Future<List<Object?>> commit({bool? exclusive, bool? noResult, bool? continueOnError}) async {
    expect(noResult, isTrue);
    if (db.fail) throw StateError('disk failure');
    db.batches++;
    db.inserts += rows.length;
    db.fingerprint = rows.last.$2['value'] as String;
    return [];
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
Word word(int id, [String definition = '苹果']) => Word(id: id, headword: 'word$id', lemma: 'word$id', level: 'A1', pos: 'n.', cnDefs: [definition]);
void main() {
  test('index batches once, skips unchanged, invalidates on content and import', () async {
    final db = _Database();
    final repo = SqliteProgressRepository.withDatabase(_Words(), db);
    await repo.indexLegacyLexicon([word(1)]);
    expect(db.batches, 1);
    expect(db.inserts, 5); // four index rows plus atomic marker
    await repo.indexLegacyLexicon([word(1)]);
    expect(db.batches, 1);
    await repo.indexLegacyLexicon([word(1, '香蕉')]);
    expect(db.batches, 2);
    await repo.importProgress({'version': 3, 'cardStates': [], 'testRuns': [], 'attempts': []});
    expect(db.fingerprint, isNull);
    await repo.indexLegacyLexicon([word(1, '香蕉')]);
    expect(db.batches, 3);
  });
  test('failed batch cannot cache completion; fingerprint ignores input order', () async {
    final db = _Database()..fail = true;
    final repo = SqliteProgressRepository.withDatabase(_Words(), db);
    await expectLater(repo.indexLegacyLexicon([word(1)]), throwsStateError);
    expect(db.fingerprint, isNull);
    db.fail = false;
    await repo.indexLegacyLexicon([word(1)]);
    expect(db.batches, 1);
    expect(SqliteProgressRepository.lexiconFingerprint([word(1), word(2)]),
        SqliteProgressRepository.lexiconFingerprint([word(2), word(1)]));
  });
}
