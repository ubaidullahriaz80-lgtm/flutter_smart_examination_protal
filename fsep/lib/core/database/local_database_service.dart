import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_key_storage.dart';
import 'local_database_schema.dart';

/// Service managing encrypted local SQLite storage.
class LocalDatabaseService {
  LocalDatabaseService({DatabaseKeyStorage? keyStorage, String? testDbPath})
      : _keyStorage = keyStorage ?? DatabaseKeyStorage.instance,
        _testDbPath = testDbPath;

  static final LocalDatabaseService instance = LocalDatabaseService();

  final DatabaseKeyStorage _keyStorage;
  final String? _testDbPath;

  Database? _database;
  bool _ffiInitialized = false;

  static const String _fileName = 'fsep_local.db';

  static bool get isSupportedOnThisPlatform => !kIsWeb;

  Future<Database> open() async {
    if (_database != null) {
      return _database!;
    }

    if (!isSupportedOnThisPlatform) {
      throw UnsupportedError(
        'LocalDatabaseService is not supported on this platform (Web).',
      );
    }

    if (!_ffiInitialized) {
      sqfliteFfiInit();
      _ffiInitialized = true;
    }

    final path = await _resolvePath();
    final key = await _keyStorage.getOrCreateKey();

    final database = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: LocalDatabaseSchema.version,
        onConfigure: (db) async {
          await db.execute("PRAGMA key = '$key';");
        },
        onCreate: (db, version) async {
          for (final statement in LocalDatabaseSchema.createStatements) {
            await db.execute(statement);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            for (final statement in LocalDatabaseSchema.upgradeToV2) {
              await db.execute(statement);
            }
          }
          if (oldVersion < 3) {
            for (final statement in LocalDatabaseSchema.upgradeToV3) {
              await db.execute(statement);
            }
          }
          if (oldVersion < 4) {
            for (final statement in LocalDatabaseSchema.upgradeToV4) {
              await db.execute(statement);
            }
          }
          if (oldVersion < 5) {
            for (final statement in LocalDatabaseSchema.upgradeToV5) {
              await db.execute(statement);
            }
          }
          if (oldVersion < 6) {
            for (final statement in LocalDatabaseSchema.upgradeToV6) {
              await db.execute(statement);
            }
          }
          if (oldVersion < 7) {
            for (final statement in LocalDatabaseSchema.upgradeToV7) {
              await db.execute(statement);
            }
            await db.execute(
              "UPDATE ${LocalDatabaseSchema.tableBehaviorEvents} "
              "SET client_uuid = hex(randomblob(16)) "
              "WHERE client_uuid IS NULL;",
            );
          }
          if (oldVersion < 8) {
            for (final statement in LocalDatabaseSchema.upgradeToV8) {
              await db.execute(statement);
            }
          }
          if (oldVersion < 9) {
            for (final statement in LocalDatabaseSchema.upgradeToV9) {
              await db.execute(statement);
            }
          }
          if (oldVersion < 10) {
            for (final statement in LocalDatabaseSchema.upgradeToV10) {
              await db.execute(statement);
            }
          }
          if (oldVersion < 11) {
            for (final statement in LocalDatabaseSchema.upgradeToV11) {
              await db.execute(statement);
            }
          }
        },
      ),
    );

    await _verifyEncryptionActive(database);

    _database = database;
    return database;
  }

  Future<void> _verifyEncryptionActive(Database database) async {
    await database.rawQuery('SELECT count(*) FROM sqlite_master');
  }

  Future<String> _resolvePath() async {
    if (_testDbPath != null) {
      return _testDbPath;
    }
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, _fileName);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    final db = await open();
    return db.transaction(action);
  }

  Future<int> insertExam(Map<String, dynamic> row) async {
    final db = await open();
    return db.insert(
      LocalDatabaseSchema.tableExams,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getExam(int id) async {
    final db = await open();
    final rows = await db.query(
      LocalDatabaseSchema.tableExams,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> insertQuestion(Map<String, dynamic> row) async {
    final db = await open();
    return db.insert(
      LocalDatabaseSchema.tableQuestions,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getQuestionsForExam(int examId) async {
    final db = await open();
    return db.query(
      LocalDatabaseSchema.tableQuestions,
      where: 'exam_id = ?',
      whereArgs: [examId],
    );
  }

  Future<int> deleteQuestionsForExam(int examId) async {
    final db = await open();
    return db.delete(
      LocalDatabaseSchema.tableQuestions,
      where: 'exam_id = ?',
      whereArgs: [examId],
    );
  }

  Future<int> insertExamSession(Map<String, dynamic> row) async {
    final db = await open();
    return db.insert(LocalDatabaseSchema.tableExamSessions, row);
  }

  Future<Map<String, dynamic>?> getExamSession(int localId) async {
    final db = await open();
    final rows = await db.query(
      LocalDatabaseSchema.tableExamSessions,
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> insertAnswer(Map<String, dynamic> row) async {
    final db = await open();
    return db.insert(LocalDatabaseSchema.tableAnswers, row);
  }

  Future<List<Map<String, dynamic>>> getAnswersForSession(
    int sessionLocalId,
  ) async {
    final db = await open();
    return db.query(
      LocalDatabaseSchema.tableAnswers,
      where: 'session_local_id = ?',
      whereArgs: [sessionLocalId],
    );
  }

  Future<Map<String, dynamic>?> getExamSessionByServerId(
    int serverSessionId,
  ) async {
    final db = await open();
    final rows = await db.query(
      LocalDatabaseSchema.tableExamSessions,
      where: 'server_session_id = ?',
      whereArgs: [serverSessionId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> insertBehaviorEvent(Map<String, dynamic> row) async {
    final db = await open();
    return db.insert(LocalDatabaseSchema.tableBehaviorEvents, row);
  }

  Future<List<Map<String, dynamic>>> getBehaviorEventsForSession(
    int sessionId,
  ) async {
    final db = await open();
    return db.query(
      LocalDatabaseSchema.tableBehaviorEvents,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllPendingBehaviorEvents() async {
    final db = await open();
    return db.query(
      LocalDatabaseSchema.tableBehaviorEvents,
      orderBy: 'created_at ASC',
    );
  }

  Future<int> deleteBehaviorEvent(int localId) async {
    final db = await open();
    return db.delete(
      LocalDatabaseSchema.tableBehaviorEvents,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }
}
