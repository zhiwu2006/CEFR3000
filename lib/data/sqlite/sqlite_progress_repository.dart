import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';

import '../../domain/srs.dart';
import '../../features/lexicon/domain/lexicon_models.dart';
import '../../features/memory/domain/learning_item_state.dart';
import '../../features/progress/domain/memory_analytics.dart';
import '../../features/progress/domain/study_streak.dart';
import '../../features/memory/domain/memory_replay.dart';
import '../../features/sync/domain/sync_repository.dart';
import '../../models/models.dart';
import '../exposure_repository.dart';
import '../learning_item_state_repository.dart';
import '../progress_repository.dart';
import '../review_commit_repository.dart';
import '../word_repository.dart';
import '../word_preference_repository.dart';
import '../migration/legacy_progress_migrator.dart';

/// SQLite-backed progress store for the learning core.
///
/// Complex legacy models are kept as versioned JSON payloads while the
/// columns used by planning and history are indexed separately. This keeps
/// the migration reversible and gives the review commit a real transaction.
class SqliteProgressRepository
    implements
        ProgressRepository,
        LeechPolicyProgressRepository,
        ReviewCommitRepository,
        TransactionalRecallRepository,
        ExposureRepository,
        LearningItemStateRepository,
        WordPreferenceRepository,
        MigrationTarget,
        SyncableProgressRepository {
  static const int schemaVersion = 2;
  static const String databaseFileName = 'vocab_learning_core.db';

  final WordRepository _wordRepository;
  final String? databasePath;
  Database? _database;

  SqliteProgressRepository(this._wordRepository, {this.databasePath});

  /// Inject an already opened database for repository contract tests.
  SqliteProgressRepository.withDatabase(this._wordRepository, Database database)
    : databasePath = null,
      _database = database;

  Database get _db {
    final database = _database;
    if (database == null) {
      throw StateError('SqliteProgressRepository.init() must be called first');
    }
    return database;
  }

  /// Whether the target database already contains user-owned migrated data.
  /// Preferences count too: a migration must never erase a user's recent
  /// suspend/restore choice just because they have not reviewed a card yet.
  @override
  Future<bool> hasCoreData() async {
    final tables = [
      'card_states',
      'review_events',
      'attempts',
      'exposure_events',
      'learning_item_states',
      'word_preferences',
    ];
    for (final table in tables) {
      final rows = await _db.rawQuery('SELECT COUNT(*) AS count FROM $table');
      if ((rows.first['count'] as num?)?.toInt() != 0) return true;
    }
    return false;
  }

  @override
  Future<void> recordMigrationRun({
    required String id,
    required int sourceSchema,
    required String sourceChecksum,
    required DateTime startedAt,
    DateTime? finishedAt,
    required String status,
    required Map<String, dynamic> report,
  }) async {
    await _db.insert('migration_runs', {
      'id': id,
      'source_schema': sourceSchema,
      'source_checksum': sourceChecksum,
      'started_at': startedAt.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'status': status,
      'report': jsonEncode(report),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, dynamic>?> latestMigrationReport() async {
    final rows = await _db.query(
      'migration_runs',
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = jsonDecode(rows.first['report']! as String);
    return Map<String, dynamic>.from(value as Map);
  }

  static const _lexiconIndexKey = 'legacyLexiconIndex:v1';

  /// Hash content, not just word count. Changing the mapper requires a key bump.
  static String lexiconFingerprint(Iterable<Word> words) {
    final sorted = words.toList()..sort((a, b) => a.id.compareTo(b.id));
    return sha256
        .convert(
          utf8.encode(jsonEncode(sorted.map((word) => word.toJson()).toList())),
        )
        .toString();
  }

  /// Unchanged installations skip the inserts: one metadata lookup after
  /// hashing the word list, instead of thousands of row writes.
  /// Additive indexing preserves reviewed content and all learning state.
  Future<void> indexLegacyLexicon(Iterable<Word> words) async {
    final snapshot = words.toList(growable: false);
    final fingerprint = lexiconFingerprint(snapshot);
    final mapper = const LegacyLexiconMapper();
    await _db.transaction((txn) async {
      final metadata = await txn.query(
        'meta',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [_lexiconIndexKey],
      );
      if (metadata.isNotEmpty && metadata.first['value'] == fingerprint) return;
      final batch = txn.batch();
      for (final word in snapshot) {
        final mapped = mapper.mapWord(word);
        final items = mapper.defaultItemsFor(mapped.sense);
        batch.insert('lexemes', {
          'stable_id': mapped.lexeme.stableId,
          'legacy_word_id': mapped.lexeme.legacyWordId,
          'content_version': mapped.lexeme.contentVersion,
          'payload': jsonEncode(mapped.lexeme.toJson()),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        batch.insert('senses', {
          'id': mapped.sense.id,
          'lexeme_id': mapped.sense.lexemeId,
          'part_of_speech': mapped.sense.partOfSpeech,
          'quality_status': mapped.sense.qualityStatus,
          'payload': jsonEncode(mapped.sense.toJson()),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        for (final item in items) {
          batch.insert('learning_items', {
            'id': item.id,
            'sense_id': item.senseId,
            'skill': item.skill.name,
            'enabled': item.enabled ? 1 : 0,
            'payload': jsonEncode(item.toJson()),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      batch.insert('meta', {
        'key': _lexiconIndexKey,
        'value': fingerprint,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<LearningItemState?> getLearningItemState(String itemId) async {
    final rows = await _db.query(
      'learning_item_states',
      where: 'item_id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LearningItemState.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(rows.first['payload']! as String) as Map,
      ),
    );
  }

  @override
  Future<void> saveLearningItemState(LearningItemState state) async {
    await _db.insert('learning_item_states', {
      'item_id': state.itemId,
      'lexeme_id': state.lexemeId,
      'skill': state.skill.name,
      'due_at': state.dueAt.toIso8601String(),
      'revision': state.revision,
      'payload': jsonEncode(state.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<LearningItemState>> getLearningItemStates({
    String? lexemeId,
  }) async {
    final rows = await _db.query(
      'learning_item_states',
      where: lexemeId == null ? null : 'lexeme_id = ?',
      whereArgs: lexemeId == null ? null : [lexemeId],
      orderBy: 'item_id ASC',
    );
    return rows
        .map(
          (row) => LearningItemState.fromJson(
            Map<String, dynamic>.from(
              jsonDecode(row['payload']! as String) as Map,
            ),
          ),
        )
        .toList();
  }

  @override
  Future<UserWordPreference?> getWordPreference(String lexemeId) async {
    final rows = await _db.query(
      'word_preferences',
      where: 'lexeme_id = ?',
      whereArgs: [lexemeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserWordPreference.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(rows.first['payload']! as String) as Map,
      ),
    );
  }

  @override
  Future<List<UserWordPreference>> getWordPreferences() async {
    final rows = await _db.query('word_preferences', orderBy: 'lexeme_id ASC');
    return rows
        .map(
          (row) => UserWordPreference.fromJson(
            Map<String, dynamic>.from(
              jsonDecode(row['payload']! as String) as Map,
            ),
          ),
        )
        .toList();
  }

  @override
  Future<void> saveWordPreference(UserWordPreference preference) async {
    await _db.insert('word_preferences', {
      'lexeme_id': preference.lexemeId,
      'suspended': preference.suspended ? 1 : 0,
      'self_declared_known': preference.selfDeclaredKnown ? 1 : 0,
      'manual_difficult': preference.manualDifficult ? 1 : 0,
      'updated_at': preference.updatedAt.toIso8601String(),
      'payload': jsonEncode(preference.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clearWordPreference(String lexemeId) async {
    await _db.delete(
      'word_preferences',
      where: 'lexeme_id = ?',
      whereArgs: [lexemeId],
    );
  }

  Future<void> init() async {
    if (_database != null) return;
    final path =
        databasePath ?? '${await getDatabasesPath()}/$databaseFileName';
    _database = await openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        // PRAGMA journal_mode returns a row on Android and must be issued via
        // query/rawQuery rather than execute. Keeping WAL here makes the
        // commit path resilient to a background read without breaking the
        // sqflite Android binding.
        await db.rawQuery('PRAGMA journal_mode = WAL');
      },
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createSchema(db);
      },
    );
    await recoverPendingReviews();
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS card_states (
        word_id INTEGER PRIMARY KEY,
        revision INTEGER NOT NULL,
        due_at TEXT NOT NULL,
        lapses INTEGER NOT NULL,
        flags INTEGER NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS test_runs (
        id TEXT PRIMARY KEY,
        started_at TEXT NOT NULL,
        finished_at TEXT,
        payload TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attempts (
        storage_key TEXT PRIMARY KEY,
        word_id INTEGER NOT NULL,
        occurred_at TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS review_events (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        word_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        before_revision INTEGER NOT NULL,
        resulting_revision INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        local_date TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exposure_events (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        word_id INTEGER NOT NULL,
        local_date TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS migration_runs (
        id TEXT PRIMARY KEY,
        source_schema INTEGER NOT NULL,
        source_checksum TEXT NOT NULL,
        started_at TEXT NOT NULL,
        finished_at TEXT,
        status TEXT NOT NULL,
        report TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lexemes (
        stable_id TEXT PRIMARY KEY,
        legacy_word_id INTEGER UNIQUE NOT NULL,
        content_version TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS senses (
        id TEXT PRIMARY KEY,
        lexeme_id TEXT NOT NULL,
        part_of_speech TEXT NOT NULL,
        quality_status TEXT NOT NULL,
        payload TEXT NOT NULL,
        FOREIGN KEY (lexeme_id) REFERENCES lexemes(stable_id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS learning_items (
        id TEXT PRIMARY KEY,
        sense_id TEXT NOT NULL,
        skill TEXT NOT NULL,
        enabled INTEGER NOT NULL,
        payload TEXT NOT NULL,
        FOREIGN KEY (sense_id) REFERENCES senses(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS learning_item_states (
        item_id TEXT PRIMARY KEY,
        lexeme_id TEXT NOT NULL,
        skill TEXT NOT NULL,
        due_at TEXT NOT NULL,
        revision INTEGER NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_preferences (
        lexeme_id TEXT PRIMARY KEY,
        suspended INTEGER NOT NULL,
        self_declared_known INTEGER NOT NULL,
        manual_difficult INTEGER NOT NULL,
        updated_at TEXT NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_card_states_due ON card_states(due_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_review_events_session ON review_events(session_id, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_review_events_date ON review_events(local_date, created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_exposure_events_word_date ON exposure_events(word_id, local_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_attempts_word_time ON attempts(word_id, occurred_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lexemes_legacy_id ON lexemes(legacy_word_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_learning_items_sense ON learning_items(sense_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_learning_item_states_lexeme ON learning_item_states(lexeme_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_word_preferences_suspended ON word_preferences(suspended)',
    );
    await db.insert('meta', {
      'key': 'schemaVersion',
      'value': schemaVersion.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }

  @override
  Future<CardState?> getCardState(int wordId) async {
    final rows = await _db.query(
      'card_states',
      where: 'word_id = ?',
      whereArgs: [wordId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _decodeCardState(rows.first['payload']);
  }

  /// SQLite 绑定参数上限。`SQLITE_MAX_VARIABLE_NUMBER` 在 SQLite 3.32.0
  /// （2020-05-22）之前为 999，之后提升到 32766；Android 7.0~11 自带的
  /// SQLite 均低于 3.32（3.9/3.18/3.22/3.26/3.28），因此单条语句绑定上千个
  /// `?` 会直接抛 "too many SQL variables"。
  /// `getWordStatuses` 会把整个等级词库的 id 传进来（可达数千），必须分片。
  static const int _maxSqlVariables = 800;

  @override
  Future<List<CardState>> getCardStates(List<int> wordIds) async {
    if (wordIds.isEmpty) return [];
    final byId = <int, CardState>{};
    // 分片查询：每片参数个数都远低于旧版 SQLite 的 999 上限，
    // 同时避免为整个词库构造一条超长 IN 列表。
    for (var start = 0; start < wordIds.length; start += _maxSqlVariables) {
      final end = (start + _maxSqlVariables).clamp(0, wordIds.length);
      final chunk = wordIds.sublist(start, end);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _db.query(
        'card_states',
        where: 'word_id IN ($placeholders)',
        whereArgs: chunk,
      );
      for (final row in rows) {
        final state = _decodeCardState(row['payload']);
        byId[state.wordId] = state;
      }
    }
    return wordIds.map((id) => byId[id]).whereType<CardState>().toList();
  }

  @override
  Future<void> saveCardState(CardState cardState) async {
    await _db.insert(
      'card_states',
      _cardStateRow(cardState),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> batchUpdateCardStates(Map<int, CardState> states) async {
    if (states.isEmpty) return;
    await _db.transaction((txn) async {
      for (final state in states.values) {
        await txn.insert(
          'card_states',
          _cardStateRow(state),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<List<Word>> getDueWords(Set<String> levels) async {
    final rows = await _db.query(
      'card_states',
      columns: ['word_id'],
      where: 'due_at <= ?',
      whereArgs: [DateTime.now().toIso8601String()],
      orderBy: 'due_at ASC',
    );
    final ids = rows
        .map((row) => (row['word_id'] as num).toInt())
        .toList(growable: false);
    final words = await _wordRepository.getByIds(ids);
    final wordMap = {for (final word in words) word.id: word};
    return ids
        .where((id) => wordMap.containsKey(id))
        .map((id) => wordMap[id]!)
        .where((word) => levels.contains(word.level))
        .toList();
  }

  @override
  Future<List<Word>> getLeechWords(Set<String> levels) async =>
      getLeechWordsWithPolicy(levels, LeechPolicy.defaultPolicy);

  @override
  Future<List<Word>> getLeechWordsWithPolicy(
    Set<String> levels,
    LeechPolicy policy,
  ) async {
    final rows = await _db.query('card_states', columns: ['payload']);
    final ids = rows
        .map((row) => _decodeCardState(row['payload']))
        .where(policy.isLeech)
        .map((state) => state.wordId)
        .toList();
    final words = await _wordRepository.getByIds(ids);
    final byId = {for (final word in words) word.id: word};
    return ids
        .where((id) => byId.containsKey(id))
        .map((id) => byId[id]!)
        .where((word) => levels.contains(word.level))
        .toList();
  }

  @override
  Future<void> resetWordProgress(int wordId) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'card_states',
        where: 'word_id = ?',
        whereArgs: [wordId],
      );
      await txn.delete(
        'learning_item_states',
        where: 'lexeme_id = ?',
        whereArgs: ['legacy:$wordId'],
      );
    });
  }

  @override
  Future<void> markWordKnown(int wordId) async {
    final current = await getCardState(wordId);
    final now = DateTime.now();
    final state = CardState(
      wordId: wordId,
      stability: 20,
      difficulty: 1.6,
      due: now.add(const Duration(days: 30)),
      lapses: 0,
      rtP50: current?.rtP50 ?? 0,
      flags:
          ((current?.flags ?? 0) & ~CardState.difficultFlag) |
          CardState.manuallyKnownFlag,
      lastReview: now,
      longTermReviews: current?.longTermReviews ?? 0,
      revision: (current?.revision ?? 0) + 1,
    );
    await saveCardState(state);
  }

  @override
  Future<void> markWordDifficult(int wordId) async {
    final current = await getCardState(wordId) ?? CardState.newCard(wordId);
    await saveCardState(current.markDifficult());
  }

  @override
  Future<void> unmarkWordDifficult(int wordId) async {
    final current = await getCardState(wordId);
    if (current != null) await saveCardState(current.unmarkDifficult());
  }

  @override
  Future<List<Word>> getNewWords(Set<String> levels, int limit) async {
    if (limit <= 0) return [];
    final words = await _wordRepository.loadByLevels(levels);
    final stateRows = await _db.query('card_states', columns: ['word_id']);
    final exposureRows = await _db.query(
      'exposure_events',
      columns: ['word_id'],
    );
    final learned = {
      ...stateRows.map((row) => (row['word_id'] as num).toInt()),
      ...exposureRows.map((row) => (row['word_id'] as num).toInt()),
    };
    final result = words.where((word) => !learned.contains(word.id)).toList();
    result.sort((a, b) => a.id.compareTo(b.id));
    return result.take(limit).toList();
  }

  @override
  Future<void> saveTestRun(TestRun testRun) async {
    await _db.insert('test_runs', {
      'id': testRun.id,
      'started_at': testRun.startedAt.toIso8601String(),
      'finished_at': testRun.finishedAt?.toIso8601String(),
      'payload': jsonEncode(testRun.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<TestRun>> getTestRunHistory({int limit = 10}) async {
    final rows = await _db.query(
      'test_runs',
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map((row) => _decodeTestRun(row['payload'])).toList();
  }

  @override
  Future<TestRun?> getLatestTestRun() async {
    final runs = await getTestRunHistory(limit: 1);
    return runs.isEmpty ? null : runs.first;
  }

  @override
  Future<void> batchSaveAttempts(List<Attempt> attempts) async {
    if (attempts.isEmpty) return;
    await _db.transaction((txn) async {
      for (final attempt in attempts) {
        await txn.insert('attempts', {
          'storage_key': _attemptStorageKey(attempt),
          'word_id': attempt.wordId,
          'occurred_at': attempt.timestamp.toIso8601String(),
          'payload': jsonEncode(attempt.toJson()),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  @override
  Future<List<WordStudyStatus>> getWordStatuses(Set<String> levels) async {
    final words = await _wordRepository.loadByLevels(levels);
    final attemptRows = await _db.query('attempts', columns: ['word_id']);
    final counts = <int, int>{};
    for (final row in attemptRows) {
      final id = (row['word_id'] as num).toInt();
      counts[id] = (counts[id] ?? 0) + 1;
    }
    final states = await getCardStates(words.map((word) => word.id).toList());
    final stateMap = {for (final state in states) state.wordId: state};
    return words
        .map(
          (word) => WordStudyStatus(
            word: word,
            state: stateMap[word.id],
            attemptCount: counts[word.id] ?? 0,
          ),
        )
        .toList();
  }

  @override
  Future<List<Attempt>> getWordAttempts(int wordId, {int limit = 10}) async {
    final rows = await _db.query(
      'attempts',
      where: 'word_id = ?',
      whereArgs: [wordId],
      orderBy: 'occurred_at DESC',
      limit: limit,
    );
    return rows.map((row) => _decodeAttempt(row['payload'])).toList();
  }

  @override
  Future<ReviewCommitResult> commitReview(ReviewEvent event) async {
    final result = await commitRecall(event: event);
    return ReviewCommitResult(
      state: result.state,
      alreadyCommitted: result.alreadyCommitted,
    );
  }

  @override
  Future<TransactionalRecallResult> commitRecall({
    required ReviewEvent event,
    ExposureEvent? firstExposure,
  }) async {
    return _db.transaction((txn) async {
      final existingRows = await txn.query(
        'review_events',
        where: 'id = ?',
        whereArgs: [event.id],
        limit: 1,
      );
      final existing = existingRows.isEmpty
          ? null
          : _decodeReviewEvent(existingRows.first['payload']);
      if (existing != null && existing.isCommitted) {
        return TransactionalRecallResult(
          state:
              existing.resultingItemState?.toCardState(
                existing.resultingState.wordId,
              ) ??
              existing.resultingState,
          alreadyCommitted: true,
          firstExposureToday: false,
        );
      }

      final itemState = event.resultingItemState;
      final currentRows = itemState == null
          ? await txn.query(
              'card_states',
              where: 'word_id = ?',
              whereArgs: [event.resultingState.wordId],
              limit: 1,
            )
          : const <Map<String, Object?>>[];
      final current = currentRows.isEmpty
          ? null
          : _decodeCardState(currentRows.first['payload']);
      final currentItemRows = itemState == null
          ? const <Map<String, Object?>>[]
          : await txn.query(
              'learning_item_states',
              where: 'item_id = ?',
              whereArgs: [itemState.itemId],
              limit: 1,
            );
      final currentItem = currentItemRows.isEmpty
          ? null
          : LearningItemState.fromJson(
              Map<String, dynamic>.from(
                jsonDecode(currentItemRows.first['payload']! as String) as Map,
              ),
            );
      final currentRevision = itemState == null
          ? current?.revision ?? 0
          : currentItem?.revision ?? 0;
      final targetRevision =
          itemState?.revision ?? event.resultingState.revision;
      if (existing != null && currentRevision >= targetRevision) {
        final committed = existing.copyWith(status: 'committed');
        await txn.update(
          'review_events',
          _reviewEventRow(committed),
          where: 'id = ?',
          whereArgs: [committed.id],
        );
        return TransactionalRecallResult(
          state:
              itemState?.toCardState(event.resultingState.wordId) ?? current!,
          alreadyCommitted: true,
          firstExposureToday: false,
        );
      }
      if (existing == null && currentRevision != event.beforeRevision) {
        throw ReviewCommitConflict(
          'Card ${event.resultingState.wordId} changed from revision '
          '${event.beforeRevision} to $currentRevision before ${event.id}',
        );
      }

      final pending = event.copyWith(status: 'pending');
      await txn.insert(
        'review_events',
        _reviewEventRow(pending),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (itemState == null) {
        await txn.insert(
          'card_states',
          _cardStateRow(event.resultingState),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (itemState != null) {
        await txn.insert(
          'learning_item_states',
          _learningItemStateRow(itemState),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      final committed = event.copyWith(status: 'committed');
      await txn.update(
        'review_events',
        _reviewEventRow(committed),
        where: 'id = ?',
        whereArgs: [committed.id],
      );

      var firstExposureToday = false;
      if (firstExposure != null) {
        final existingExposure = await txn.query(
          'exposure_events',
          columns: ['id'],
          where: 'word_id = ? AND local_date = ?',
          whereArgs: [firstExposure.wordId, firstExposure.localDate],
          limit: 1,
        );
        if (existingExposure.isEmpty) {
          await txn.insert(
            'exposure_events',
            _exposureEventRow(firstExposure),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          firstExposureToday = true;
        }
      }
      return TransactionalRecallResult(
        state:
            itemState?.toCardState(event.resultingState.wordId) ??
            committed.resultingState,
        alreadyCommitted: false,
        firstExposureToday: firstExposureToday,
      );
    });
  }

  @override
  Future<void> recoverPendingReviews() async {
    final pendingRows = await _db.query(
      'review_events',
      where: 'status != ?',
      whereArgs: ['committed'],
    );
    if (pendingRows.isEmpty) return;
    await _db.transaction((txn) async {
      for (final row in pendingRows) {
        final event = _decodeReviewEvent(row['payload']);
        final itemState = event.resultingItemState;
        if (itemState == null) {
          final stateRows = await txn.query(
            'card_states',
            where: 'word_id = ?',
            whereArgs: [event.resultingState.wordId],
            limit: 1,
          );
          final current = stateRows.isEmpty
              ? null
              : _decodeCardState(stateRows.first['payload']);
          if (current == null ||
              current.revision < event.resultingState.revision) {
            await txn.insert(
              'card_states',
              _cardStateRow(event.resultingState),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
        if (itemState != null) {
          await txn.insert(
            'learning_item_states',
            _learningItemStateRow(itemState),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        final committed = event.copyWith(status: 'committed');
        await txn.update(
          'review_events',
          _reviewEventRow(committed),
          where: 'id = ?',
          whereArgs: [event.id],
        );
      }
    });
  }

  @override
  Future<ReviewEvent?> getReviewEvent(String eventId) async {
    final rows = await _db.query(
      'review_events',
      where: 'id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    return rows.isEmpty ? null : _decodeReviewEvent(rows.first['payload']);
  }

  @override
  Future<List<ReviewEvent>> getReviewEvents({String? sessionId}) async {
    final rows = await _db.query(
      'review_events',
      where: sessionId == null ? null : 'session_id = ?',
      whereArgs: sessionId == null ? null : [sessionId],
      orderBy: 'created_at ASC',
    );
    return rows.map((row) => _decodeReviewEvent(row['payload'])).toList();
  }

  @override
  Future<String?> getSyncMeta(String key) async {
    final rows = await _db.query(
      'meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['sync:$key'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> setSyncMeta(String key, String value) async {
    await _db.insert('meta', {
      'key': 'sync:$key',
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<SyncOutbox> pendingOutbox({
    required int eventsAfter,
    required int exposuresAfter,
    required int runsAfter,
    int limit = 500,
  }) async {
    Future<List<Map<String, Object?>>> rows(String table, int after) =>
        _db.query(
          table,
          columns: ['rowid', 'payload'],
          where: 'rowid > ?',
          whereArgs: [after],
          orderBy: 'rowid ASC',
          limit: limit,
        );
    final events = [
      for (final row in await rows('review_events', eventsAfter))
        (row['rowid']! as int, _decodeReviewEvent(row['payload'])),
    ];
    return SyncOutbox(
      // 未提交（pending）的事件只截到它之前，等提交后下一次再传。
      events: events.takeWhile((entry) => entry.$2.isCommitted).toList(),
      exposures: [
        for (final row in await rows('exposure_events', exposuresAfter))
          (
            row['rowid']! as int,
            ExposureEvent.fromJson(
              Map<String, dynamic>.from(
                jsonDecode(row['payload']! as String) as Map,
              ),
            ),
          ),
      ],
      runs: [
        for (final row in await rows('test_runs', runsAfter))
          (row['rowid']! as int, _decodeTestRun(row['payload'])),
      ],
    );
  }

  @override
  Future<SyncMergeResult> mergeSyncedData({
    required List<ReviewEvent> events,
    required List<ExposureEvent> exposures,
    required List<TestRun> runs,
  }) async {
    return _db.transaction((txn) async {
      final knownEventIds = {
        for (final row in await txn.query('review_events', columns: ['id']))
          row['id']! as String,
      };
      final fresh = <ReviewEvent>[
        for (final event in events)
          if (event.isCommitted && knownEventIds.add(event.id)) event,
      ];
      for (final event in fresh) {
        await txn.insert(
          'review_events',
          _reviewEventRow(event),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      var newExposures = 0;
      for (final exposure in exposures) {
        final inserted = await txn.insert(
          'exposure_events',
          _exposureEventRow(exposure),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (inserted != 0) newExposures++;
      }

      // 轮次：本地没有的插入；本地未完成而远程已完成的，以远程为准。
      var newRuns = 0;
      for (final run in runs) {
        final rows = await txn.query(
          'test_runs',
          columns: ['finished_at'],
          where: 'id = ?',
          whereArgs: [run.id],
          limit: 1,
        );
        final localFinished =
            rows.isNotEmpty && rows.first['finished_at'] != null;
        if (rows.isNotEmpty && (localFinished || run.finishedAt == null)) {
          continue;
        }
        await txn.insert('test_runs', {
          'id': run.id,
          'started_at': run.startedAt.toIso8601String(),
          'finished_at': run.finishedAt?.toIso8601String(),
          'payload': jsonEncode(run.toJson()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        newRuns++;
      }

      // 只重算识别能力的卡片：用该词全部已提交事件（本地 + 远程）重放。
      final affected = {
        for (final event in fresh)
          if (event.skill == 'meaningRecognition') event.attempt.wordId,
      }.toList();
      var rebuilt = 0;
      for (var start = 0; start < affected.length; start += _maxSqlVariables) {
        final chunk = affected.sublist(
          start,
          (start + _maxSqlVariables).clamp(0, affected.length),
        );
        final marks = List.filled(chunk.length, '?').join(',');
        final history = (await txn.query(
          'review_events',
          columns: ['payload'],
          where: 'word_id IN ($marks)',
          whereArgs: chunk,
        )).map((row) => _decodeReviewEvent(row['payload'])).toList();
        final replay = const MemoryReplay().run(history);
        final localRows = await txn.query(
          'card_states',
          columns: ['payload'],
          where: 'word_id IN ($marks)',
          whereArgs: chunk,
        );
        final local = {
          for (final row in localRows)
            _decodeCardState(row['payload']).wordId: _decodeCardState(
              row['payload'],
            ),
        };
        for (final entry in replay.legacyStates.entries) {
          final before = local[entry.key];
          // 保留用户标记（疑难等），revision 必须单调递增，后续提交才不冲突。
          final next = entry.value.copyWith(
            flags: before?.flags ?? entry.value.flags,
            revision:
                [
                  before?.revision ?? 0,
                  entry.value.revision,
                ].reduce((a, b) => a > b ? a : b) +
                1,
          );
          await txn.insert(
            'card_states',
            _cardStateRow(next),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          rebuilt++;
        }
      }

      return SyncMergeResult(
        newEvents: fresh.length,
        newExposures: newExposures,
        newRuns: newRuns,
        rebuiltCards: rebuilt,
      );
    });
  }

  @override
  Future<bool> recordExposure(ExposureEvent event) async {
    final result = await _db.insert(
      'exposure_events',
      _exposureEventRow(event),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return result != 0;
  }

  @override
  Future<bool> hasExposureForDate({
    required int wordId,
    required String localDate,
  }) async {
    final rows = await _db.query(
      'exposure_events',
      columns: ['id'],
      where: 'word_id = ? AND local_date = ?',
      whereArgs: [wordId, localDate],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  @override
  Future<List<ExposureEvent>> getExposureEvents({String? sessionId}) async {
    final rows = await _db.query(
      'exposure_events',
      where: sessionId == null ? null : 'session_id = ?',
      whereArgs: sessionId == null ? null : [sessionId],
      orderBy: 'occurred_at ASC',
    );
    return rows.map((row) => _decodeExposureEvent(row['payload'])).toList();
  }

  @override
  Future<Map<String, dynamic>> getLearningStats({
    LeechPolicy policy = LeechPolicy.defaultPolicy,
  }) async {
    final states = await _allCardStates();
    final runs = await getTestRunHistory(limit: 100000);
    final attempts = await _allAttempts();
    final itemStates = await getLearningItemStates();
    final events = (await getReviewEvents())
        .where((event) => event.isCommitted)
        .toList();
    final exposures = await getExposureEvents();
    final due = states.where((state) => state.isDue).length;
    final leeches = states.where(policy.isLeech).length;
    final mastered = states.where((state) => state.isMastered).length;
    final independentDue = events
        .where((event) => event.isDueReview && event.independentRecall)
        .toList();
    final accuracy = events.isNotEmpty
        ? events.where((event) => event.isSuccessful).length / events.length
        : attempts.isEmpty
        ? 0.0
        : attempts.where((attempt) => attempt.isCorrect).length /
              attempts.length;
    final retention = independentDue.isEmpty
        ? accuracy
        : independentDue.where((event) => event.isSuccessful).length /
              independentDue.length;
    final stability = states.isEmpty
        ? 0.0
        : states.fold<double>(0, (sum, state) => sum + state.stability) /
              states.length;
    final difficulty = states.isEmpty
        ? 0.0
        : states.fold<double>(0, (sum, state) => sum + state.difficulty) /
              states.length;
    final today = _localDate(DateTime.now());
    return {
      'totalCards': states.length,
      'dueCards': due,
      'leechCards': leeches,
      'masteredCards': mastered,
      'manuallyKnownCards': states
          .where((state) => state.isManuallyKnown)
          .length,
      'retentionRate': retention,
      'avgAccuracy': accuracy,
      'avgStability': stability,
      'avgDifficulty': difficulty,
      'totalTestRuns': runs.length,
      'finishedTestRuns': runs.where((run) => run.isFinished).length,
      'totalAttempts': attempts.length,
      'reviewEventCount': events.length,
      'exposureCount': exposures.length,
      'learningItemCount': itemStates.length,
      'learningItemDueCount': itemStates
          .where((state) => !state.dueAt.isAfter(DateTime.now()))
          .length,
      'learningItemMasteredCount': itemStates
          .where((state) => state.isMastered)
          .length,
      'todayNewWordCount': exposures
          .where((event) => event.localDate == today)
          .map((event) => event.wordId)
          .toSet()
          .length,
      'independentDueReviewCount': independentDue.length,
      'independentDueSuccessCount': independentDue
          .where((event) => event.isSuccessful)
          .length,
      ...StudyStreak.fromRuns(runs).toJson(),
      ...MemoryAnalytics.summarize(events),
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getDailyStats(int days) async {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    final result = List<Map<String, dynamic>>.generate(days, (index) {
      final date = start.add(Duration(days: index));
      return {
        'date': date,
        'durationMs': 0,
        'accuracy': 0.0,
        'count': 0,
        'totalAttempts': 0,
        'correctAttempts': 0,
      };
    });
    final events = (await getReviewEvents())
        .where((event) => event.isCommitted)
        .toList();
    for (final event in events) {
      final date = DateTime.tryParse(event.localDate) ?? event.createdAt;
      final day = DateTime(date.year, date.month, date.day);
      final index = day.difference(start).inDays;
      if (index < 0 || index >= result.length) continue;
      final row = result[index];
      row['count'] = (row['count'] as int) + 1;
      row['totalAttempts'] = (row['totalAttempts'] as int) + 1;
      row['correctAttempts'] =
          (row['correctAttempts'] as int) + (event.isSuccessful ? 1 : 0);
      row['durationMs'] = (row['durationMs'] as int) + event.activeDurationMs;
    }
    for (final row in result) {
      final total = row['totalAttempts'] as int;
      row['accuracy'] = total == 0
          ? 0.0
          : (row['correctAttempts'] as int) / total;
    }
    return result;
  }

  @override
  Future<Map<String, int>> getLevelProgress(Set<String> levels) async {
    final words = await _wordRepository.loadByLevels(levels);
    final ids = words.map((word) => word.id).toSet();
    final states = (await _allCardStates())
        .where((state) => ids.contains(state.wordId))
        .toList();
    final learned = states.length;
    final mastered = states.where((state) => state.isMastered).length;
    return {
      'total': words.length,
      'learned': learned,
      'mastered': mastered,
      'notStarted': words.length - learned,
    };
  }

  @override
  Future<void> clearAllProgress() async {
    await _db.transaction((txn) async {
      for (final table in [
        'card_states',
        'test_runs',
        'attempts',
        'review_events',
        'exposure_events',
        'learning_item_states',
        'word_preferences',
      ]) {
        await txn.delete(table);
      }
    });
  }

  @override
  Future<void> clearTestRuns() async => _db.delete('test_runs');

  @override
  Future<void> clearAttempts() async {
    await _db.transaction((txn) async {
      await txn.delete('attempts');
      await txn.delete('review_events');
      await txn.delete('exposure_events');
    });
  }

  @override
  Future<void> clearCardStates() async {
    await _db.transaction((txn) async {
      await txn.delete('card_states');
      await txn.delete('learning_item_states');
    });
  }

  @override
  Future<Map<String, dynamic>> exportProgress() async {
    return {
      'version': 3,
      'storage': 'sqlite',
      'schemaVersion': schemaVersion,
      'cardStates': (await _allCardStates())
          .map((state) => state.toJson())
          .toList(),
      'testRuns': (await getTestRunHistory(
        limit: 100000,
      )).map((run) => run.toJson()).toList(),
      'attempts': (await _allAttempts())
          .map((attempt) => attempt.toJson())
          .toList(),
      'reviewEvents': (await getReviewEvents())
          .map((event) => event.toJson())
          .toList(),
      'exposureEvents': (await getExposureEvents())
          .map((event) => event.toJson())
          .toList(),
      'lexemes': (await _db.query(
        'lexemes',
        orderBy: 'legacy_word_id ASC',
      )).map((row) => jsonDecode(row['payload']! as String)).toList(),
      'senses': (await _db.query(
        'senses',
        orderBy: 'id ASC',
      )).map((row) => jsonDecode(row['payload']! as String)).toList(),
      'learningItems': (await _db.query(
        'learning_items',
        orderBy: 'id ASC',
      )).map((row) => jsonDecode(row['payload']! as String)).toList(),
      'learningItemStates': (await getLearningItemStates())
          .map((state) => state.toJson())
          .toList(),
      'wordPreferences': (await getWordPreferences())
          .map((preference) => preference.toJson())
          .toList(),
      'exportTime': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<void> importProgress(Map<String, dynamic> data) async {
    await _db.transaction((txn) async {
      await txn.delete('meta', where: 'key = ?', whereArgs: [_lexiconIndexKey]);
      for (final table in [
        'card_states',
        'test_runs',
        'attempts',
        'review_events',
        'exposure_events',
        'learning_item_states',
        'word_preferences',
        'learning_items',
        'senses',
        'lexemes',
      ]) {
        await txn.delete(table);
      }
      for (final raw in (data['cardStates'] as List? ?? const [])) {
        final state = CardState.fromJson(Map<String, dynamic>.from(raw as Map));
        await txn.insert('card_states', _cardStateRow(state));
      }
      for (final raw in (data['testRuns'] as List? ?? const [])) {
        final run = TestRun.fromJson(Map<String, dynamic>.from(raw as Map));
        await txn.insert('test_runs', {
          'id': run.id,
          'started_at': run.startedAt.toIso8601String(),
          'finished_at': run.finishedAt?.toIso8601String(),
          'payload': jsonEncode(run.toJson()),
        });
      }
      for (final raw in (data['attempts'] as List? ?? const [])) {
        final attempt = Attempt.fromJson(Map<String, dynamic>.from(raw as Map));
        await txn.insert('attempts', {
          'storage_key': _attemptStorageKey(attempt),
          'word_id': attempt.wordId,
          'occurred_at': attempt.timestamp.toIso8601String(),
          'payload': jsonEncode(attempt.toJson()),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final raw in (data['reviewEvents'] as List? ?? const [])) {
        final event = ReviewEvent.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        await txn.insert('review_events', _reviewEventRow(event));
      }
      for (final raw in (data['exposureEvents'] as List? ?? const [])) {
        final event = ExposureEvent.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        await txn.insert('exposure_events', _exposureEventRow(event));
      }
      for (final raw in (data['lexemes'] as List? ?? const [])) {
        final lexeme = Lexeme.fromJson(Map<String, dynamic>.from(raw as Map));
        await txn.insert('lexemes', {
          'stable_id': lexeme.stableId,
          'legacy_word_id': lexeme.legacyWordId,
          'content_version': lexeme.contentVersion,
          'payload': jsonEncode(lexeme.toJson()),
        });
      }
      for (final raw in (data['senses'] as List? ?? const [])) {
        final sense = Sense.fromJson(Map<String, dynamic>.from(raw as Map));
        await txn.insert('senses', {
          'id': sense.id,
          'lexeme_id': sense.lexemeId,
          'part_of_speech': sense.partOfSpeech,
          'quality_status': sense.qualityStatus,
          'payload': jsonEncode(sense.toJson()),
        });
      }
      for (final raw in (data['learningItems'] as List? ?? const [])) {
        final item = LearningItem.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        await txn.insert('learning_items', {
          'id': item.id,
          'sense_id': item.senseId,
          'skill': item.skill.name,
          'enabled': item.enabled ? 1 : 0,
          'payload': jsonEncode(item.toJson()),
        });
      }
      for (final raw in (data['learningItemStates'] as List? ?? const [])) {
        final state = LearningItemState.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        await txn.insert('learning_item_states', {
          'item_id': state.itemId,
          'lexeme_id': state.lexemeId,
          'skill': state.skill.name,
          'due_at': state.dueAt.toIso8601String(),
          'revision': state.revision,
          'payload': jsonEncode(state.toJson()),
        });
      }
      for (final raw in (data['wordPreferences'] as List? ?? const [])) {
        final preference = UserWordPreference.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        await txn.insert('word_preferences', {
          'lexeme_id': preference.lexemeId,
          'suspended': preference.suspended ? 1 : 0,
          'self_declared_known': preference.selfDeclaredKnown ? 1 : 0,
          'manual_difficult': preference.manualDifficult ? 1 : 0,
          'updated_at': preference.updatedAt.toIso8601String(),
          'payload': jsonEncode(preference.toJson()),
        });
      }
    });
  }

  Map<String, dynamic> _cardStateRow(CardState state) => {
    'word_id': state.wordId,
    'revision': state.revision,
    'due_at': state.due.toIso8601String(),
    'lapses': state.lapses,
    'flags': state.flags,
    'payload': jsonEncode(state.toJson()),
  };

  Map<String, dynamic> _reviewEventRow(ReviewEvent event) => {
    'id': event.id,
    'session_id': event.sessionId,
    'word_id': event.resultingState.wordId,
    'status': event.status,
    'before_revision': event.beforeRevision,
    'resulting_revision': event.resultingState.revision,
    'created_at': event.createdAt.toIso8601String(),
    'local_date': event.localDate,
    'payload': jsonEncode(event.toJson()),
  };

  Map<String, dynamic> _exposureEventRow(ExposureEvent event) => {
    'id': event.id,
    'session_id': event.sessionId,
    'word_id': event.wordId,
    'local_date': event.localDate,
    'occurred_at': event.occurredAt.toIso8601String(),
    'payload': jsonEncode(event.toJson()),
  };

  Map<String, dynamic> _learningItemStateRow(LearningItemState state) => {
    'item_id': state.itemId,
    'lexeme_id': state.lexemeId,
    'skill': state.skill.name,
    'due_at': state.dueAt.toIso8601String(),
    'revision': state.revision,
    'payload': jsonEncode(state.toJson()),
  };

  CardState _decodeCardState(Object? payload) => CardState.fromJson(
    Map<String, dynamic>.from(jsonDecode(payload! as String) as Map),
  );

  TestRun _decodeTestRun(Object? payload) => TestRun.fromJson(
    Map<String, dynamic>.from(jsonDecode(payload! as String) as Map),
  );

  Attempt _decodeAttempt(Object? payload) => Attempt.fromJson(
    Map<String, dynamic>.from(jsonDecode(payload! as String) as Map),
  );

  ReviewEvent _decodeReviewEvent(Object? payload) => ReviewEvent.fromJson(
    Map<String, dynamic>.from(jsonDecode(payload! as String) as Map),
  );

  ExposureEvent _decodeExposureEvent(Object? payload) => ExposureEvent.fromJson(
    Map<String, dynamic>.from(jsonDecode(payload! as String) as Map),
  );

  Future<List<CardState>> _allCardStates() async {
    final rows = await _db.query('card_states', orderBy: 'word_id ASC');
    return rows.map((row) => _decodeCardState(row['payload'])).toList();
  }

  Future<List<Attempt>> _allAttempts() async {
    final rows = await _db.query('attempts', orderBy: 'occurred_at ASC');
    return rows.map((row) => _decodeAttempt(row['payload'])).toList();
  }

  String _attemptStorageKey(Attempt attempt) =>
      '${attempt.wordId}_${attempt.timestamp.microsecondsSinceEpoch}_'
      '${attempt.result.name}_${attempt.chosenIndex}_${attempt.correctIndex}';

  String _localDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
