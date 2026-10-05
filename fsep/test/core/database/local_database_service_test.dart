import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/database/database_key_storage.dart';
import 'package:fsep/core/database/local_database_schema.dart';
import 'package:fsep/core/database/local_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// In-memory DatabaseKeyStorage double, mirroring the existing
/// _InMemoryTokenStorage pattern (see auth_repository_test.dart) — keeps
/// full control over the exact key value without ever touching the real
/// flutter_secure_storage platform channel.
class _FixedKeyStorage extends DatabaseKeyStorage {
  _FixedKeyStorage(this.key);

  final String key;

  @override
  Future<String> getOrCreateKey() async => key;
}

void main() {
  final correctKey = 'a1b2c3d4e5f6' * 5; // arbitrary 60-char hex-ish string
  final wrongKey = 'f6e5d4c3b2a1' * 5;

  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    // Safe to call more than once per process — needed here because this
    // file also opens a database directly (Test 11) without going
    // through LocalDatabaseService.open()'s own lazy init.
    sqfliteFfiInit();
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fsep_local_db_test_');
    dbPath = '${tempDir.path}/test.db';
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  LocalDatabaseService makeService({String? key}) {
    return LocalDatabaseService(
      keyStorage: _FixedKeyStorage(key ?? correctKey),
      testDbPath: dbPath,
    );
  }

  Map<String, dynamic> sampleExam({int id = 1}) => {
        'id': id,
        'title': 'Sample Exam',
        'description': 'A cached exam for testing',
        'course_code': 'CS101',
        'duration_minutes': 60,
        'total_marks': 20.0,
        'negative_marking_weight': 0.25,
        'status': 'published',
        'cached_at': DateTime.now().toIso8601String(),
      };

  Map<String, dynamic> sampleQuestion({
    int id = 1,
    int examId = 1,
    String type = 'mcq',
    String? options,
  }) =>
      {
        'id': id,
        'exam_id': examId,
        'question_text': 'Question for $type',
        'question_type': type,
        'marks': 5.0,
        'difficulty': 'medium',
        'bloom_taxonomy': 'understand',
        'topic_tag': 'Test Topic',
        'options': options,
        'review_status': 'approved',
        'is_ai_generated': 0,
        'cached_at': DateTime.now().toIso8601String(),
      };

  Map<String, dynamic> sampleSession({int examId = 1}) => {
        'server_session_id': null,
        'exam_id': examId,
        'status': 'in_progress',
        'started_at': DateTime.now().toIso8601String(),
        'expires_at': null,
        'submitted_at': null,
        'current_question_index': 0,
        'server_clock_offset_ms': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

  test('Test 1 — database initializes successfully', () async {
    final service = makeService();
    final db = await service.open();
    expect(db.isOpen, isTrue);
    await service.close();
  });

  test('Test 2 — required tables exist', () async {
    final service = makeService();
    final db = await service.open();
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = tables.map((r) => r['name'] as String).toSet();
    expect(
      names,
      containsAll([
        LocalDatabaseSchema.tableExams,
        LocalDatabaseSchema.tableQuestions,
        LocalDatabaseSchema.tableExamSessions,
        LocalDatabaseSchema.tableAnswers,
        LocalDatabaseSchema.tableBehaviorEvents,
      ]),
    );
    await service.close();
  });

  test('Test 3 — exam can be inserted and retrieved', () async {
    final service = makeService();
    await service.insertExam(sampleExam());

    final row = await service.getExam(1);
    expect(row, isNotNull);
    expect(row!['title'], 'Sample Exam');
    expect(row['course_code'], 'CS101');
    await service.close();
  });

  test('Test 4 — question can be inserted and retrieved', () async {
    final service = makeService();
    await service.insertExam(sampleExam());
    await service.insertQuestion(
      sampleQuestion(options: '["3","4","5"]'),
    );

    final rows = await service.getQuestionsForExam(1);
    expect(rows, hasLength(1));
    expect(rows.first['question_type'], 'mcq');
    expect(rows.first['options'], '["3","4","5"]');
    await service.close();
  });

  test(
    'Test 5 — all six question types are represented without losing data',
    () async {
      final service = makeService();
      await service.insertExam(sampleExam());

      // options shapes mirror exactly what the server sends per type
      // (see QuestionController::validatedQuestionData): mcq's flat
      // list, matching's {left,right} pairs, code_snippet's
      // single-element language list, and null for the rest.
      final optionsByType = <String, String?>{
        'mcq': '["A","B","C"]',
        'true_false': null,
        'short_answer': null,
        'essay': null,
        'matching': '[{"left":"CPU","right":"Executes instructions"}]',
        'code_snippet': '["python"]',
      };

      var id = 1;
      for (final entry in optionsByType.entries) {
        await service.insertQuestion(
          sampleQuestion(id: id, type: entry.key, options: entry.value),
        );
        id++;
      }

      final rows = await service.getQuestionsForExam(1);
      expect(rows, hasLength(6));

      final byType = {
        for (final r in rows) r['question_type'] as String: r,
      };
      for (final entry in optionsByType.entries) {
        expect(
          byType[entry.key],
          isNotNull,
          reason: '${entry.key} question missing after retrieval',
        );
        expect(
          byType[entry.key]!['options'],
          entry.value,
          reason: '${entry.key} lost its options data',
        );
      }
      await service.close();
    },
  );

  test('Test 6 — an exam session can be stored', () async {
    final service = makeService();
    await service.insertExam(sampleExam());
    final localId = await service.insertExamSession(sampleSession());

    final row = await service.getExamSession(localId);
    expect(row, isNotNull);
    expect(row!['status'], 'in_progress');
    expect(row['exam_id'], 1);
    expect(row['server_session_id'], isNull);
    await service.close();
  });

  test(
    'Test 7 — an answer can be stored with synchronization metadata',
    () async {
      final service = makeService();
      await service.insertExam(sampleExam());
      final sessionLocalId = await service.insertExamSession(sampleSession());

      await service.insertAnswer({
        'session_local_id': sessionLocalId,
        'question_id': 1,
        'selected_option': 'A',
        'sync_status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'last_synced_at': null,
        'server_answer_id': null,
      });

      final rows = await service.getAnswersForSession(sessionLocalId);
      expect(rows, hasLength(1));
      expect(rows.first['sync_status'], 'pending');
      expect(rows.first['selected_option'], 'A');
      expect(rows.first['server_answer_id'], isNull);
      expect(rows.first['last_synced_at'], isNull);
      await service.close();
    },
  );

  test(
    'Test 8 — database can be closed and reopened without losing data '
    '(correct key)',
    () async {
      final first = makeService();
      await first.insertExam(sampleExam());
      await first.close();

      final second = makeService(); // same key, same file path
      final row = await second.getExam(1);
      expect(row, isNotNull);
      expect(row!['title'], 'Sample Exam');
      await second.close();
    },
  );

  test('Test 9 — repeated initialization is safe', () async {
    final service = makeService();
    await service.open();
    await service.insertExam(sampleExam());

    // Second open() call on the same instance and same underlying file.
    final db = await service.open();
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = tables.map((r) => r['name'] as String).toList();

    // No duplicate table names, and the 4 expected tables are present
    // exactly once each.
    expect(names.toSet().length, names.length);
    expect(
      names.where((n) => n == LocalDatabaseSchema.tableExams),
      hasLength(1),
    );

    // Data survived the second open() call untouched.
    final row = await service.getExam(1);
    expect(row, isNotNull);
    await service.close();
  });

  test(
    'Test 10 — encryption is active: the wrong key cannot read the data',
    () async {
      final correct = makeService();
      await correct.insertExam(sampleExam());
      await correct.close();

      final wrong = makeService(key: wrongKey);
      // SQLCipher doesn't fail at open() — it fails on the first real
      // read against the file ("file is not a database").
      await expectLater(
        wrong.open().then((db) => db.rawQuery('SELECT * FROM sqlite_master')),
        throwsA(anything),
      );
    },
  );

  test(
    'Test 11 — the database file cannot be opened as an ordinary '
    'plaintext SQLite database without the encryption key',
    () async {
      final service = makeService();
      await service.insertExam(sampleExam());
      await service.close();

      // Open the raw file with the plain (unkeyed) factory directly —
      // bypassing LocalDatabaseService entirely, exactly simulating an
      // attacker/tool trying to read the file without the passphrase.
      final plain = await databaseFactoryFfi.openDatabase(dbPath);
      await expectLater(
        plain.rawQuery("SELECT name FROM sqlite_master"),
        throwsA(anything),
      );
      await plain.close();
    },
  );

  test('Test 12 — migration v4 to v5 adds the expected columns', () async {
    // 1. Create a version 4 database manually.
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 4,
        onConfigure: (db) async => await db.execute("PRAGMA key = '$correctKey';"),
        onCreate: (db, version) async {
          // Version 1-3 migrations are already combined in createStatements
          // normally, but here we just need a v4-like state for local_exam_sessions.
          await db.execute('''
            CREATE TABLE IF NOT EXISTS local_exam_sessions (
              local_id INTEGER PRIMARY KEY AUTOINCREMENT,
              server_session_id INTEGER,
              exam_id INTEGER NOT NULL,
              status TEXT NOT NULL,
              started_at TEXT NOT NULL,
              expires_at TEXT,
              submitted_at TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    await db.close();

    // 2. Open it with LocalDatabaseService (which is now v5).
    final service = makeService();
    final upgradedDb = await service.open();

    // 3. Verify the new columns exist.
    final info = await upgradedDb.rawQuery('PRAGMA table_info(local_exam_sessions)');
    final columnNames = info.map((r) => r['name'] as String).toSet();

    expect(columnNames, contains('current_question_index'));
    expect(columnNames, contains('server_clock_offset_ms'));

    await service.close();
  });

  test('Test 13 — migration v5 to v6 creates behavior events table', () async {
    // 1. Create a version 5 database manually.
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 5,
        onConfigure: (db) async => await db.execute("PRAGMA key = '$correctKey';"),
        onCreate: (db, version) async {
          // Minimal v5 local_exam_sessions
          await db.execute('''
            CREATE TABLE IF NOT EXISTS local_exam_sessions (
              local_id INTEGER PRIMARY KEY AUTOINCREMENT,
              exam_id INTEGER NOT NULL,
              status TEXT NOT NULL,
              started_at TEXT NOT NULL,
              current_question_index INTEGER NOT NULL DEFAULT 0,
              server_clock_offset_ms INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    await db.close();

    // 2. Open it with LocalDatabaseService (which is now v6).
    final service = makeService();
    final upgradedDb = await service.open();

    // 3. Verify the new table exists.
    final tables = await upgradedDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'local_behavior_events'",
    );
    expect(tables, hasLength(1));

    await service.close();
  });
}
