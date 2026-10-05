import '../../core/database/local_database_schema.dart';
import '../../core/database/local_database_service.dart';

/// Record representing a locally offlined answer.
class PendingAnswerRecord {
  const PendingAnswerRecord({
    required this.localId,
    required this.sessionId,
    required this.questionId,
    required this.selectedOption,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
    this.conflictCode,
  });

  final int localId;
  final int sessionId;
  final int questionId;
  final String selectedOption;
  final String syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? conflictCode;

  factory PendingAnswerRecord.fromRow(Map<String, dynamic> row) {
    return PendingAnswerRecord(
      localId: row['local_id'] as int,
      sessionId: row['session_id'] as int,
      questionId: row['question_id'] as int,
      selectedOption: row['selected_option'] as String,
      syncStatus: row['sync_status'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      conflictCode: row['conflict_code'] as String?,
    );
  }
}

/// Local repository for managing offlined answers.
class PendingAnswerRepository {
  PendingAnswerRepository({LocalDatabaseService? databaseService})
      : _db = databaseService ?? LocalDatabaseService.instance;

  final LocalDatabaseService _db;

  Future<void> savePendingAnswer({
    required int sessionId,
    required int questionId,
    required String selectedOption,
  }) async {
    final now = DateTime.now().toIso8601String();

    await _db.transaction((txn) async {
      final existing = await txn.query(
        LocalDatabaseSchema.tableAnswers,
        where: 'session_id = ? AND question_id = ?',
        whereArgs: [sessionId, questionId],
        limit: 1,
      );

      if (existing.isEmpty) {
        await txn.insert(LocalDatabaseSchema.tableAnswers, {
          'session_id': sessionId,
          'question_id': questionId,
          'selected_option': selectedOption,
          'sync_status': 'pending',
          'created_at': now,
          'updated_at': now,
        });
      } else {
        await txn.update(
          LocalDatabaseSchema.tableAnswers,
          {
            'selected_option': selectedOption,
            'sync_status': 'pending',
            'updated_at': now,
          },
          where: 'local_id = ?',
          whereArgs: [existing.first['local_id']],
        );
      }
    });
  }

  Future<PendingAnswerRecord?> getPendingAnswer({
    required int sessionId,
    required int questionId,
  }) async {
    final db = await _db.open();
    final rows = await db.query(
      LocalDatabaseSchema.tableAnswers,
      where: 'session_id = ? AND question_id = ?',
      whereArgs: [sessionId, questionId],
      limit: 1,
    );
    return rows.isEmpty ? null : PendingAnswerRecord.fromRow(rows.first);
  }

  Future<List<PendingAnswerRecord>> getPendingAnswers({
    required int sessionId,
  }) async {
    final db = await _db.open();
    final rows = await db.query(
      LocalDatabaseSchema.tableAnswers,
      where: 'session_id = ? AND sync_status = ?',
      whereArgs: [sessionId, 'pending'],
    );
    return rows.map(PendingAnswerRecord.fromRow).toList();
  }

  Future<List<int>> getPendingSessionIds() async {
    final db = await _db.open();
    final rows = await db.query(
      LocalDatabaseSchema.tableAnswers,
      columns: ['session_id'],
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      distinct: true,
    );
    return rows.map((r) => r['session_id'] as int).toList();
  }

  Future<void> markSynced({
    required int sessionId,
    required int questionId,
  }) async {
    final db = await _db.open();
    await db.update(
      LocalDatabaseSchema.tableAnswers,
      {
        'sync_status': 'synced',
        'last_synced_at': DateTime.now().toIso8601String(),
        'conflict_code': null,
      },
      where: 'session_id = ? AND question_id = ?',
      whereArgs: [sessionId, questionId],
    );
  }

  Future<void> markConflict({
    required int sessionId,
    required int questionId,
    required String conflictCode,
  }) async {
    final db = await _db.open();
    await db.update(
      LocalDatabaseSchema.tableAnswers,
      {
        'sync_status': 'failed',
        'conflict_code': conflictCode,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'session_id = ? AND question_id = ?',
      whereArgs: [sessionId, questionId],
    );
  }

  Future<Map<int, String>> getAnswersForSession({
    required int sessionId,
  }) async {
    final db = await _db.open();
    final rows = await db.query(
      LocalDatabaseSchema.tableAnswers,
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return {
      for (final row in rows)
        row['question_id'] as int: row['selected_option'] as String,
    };
  }

  Future<List<PendingAnswerRecord>> getAllFailedAnswers() async {
    final db = await _db.open();
    final rows = await db.query(
      LocalDatabaseSchema.tableAnswers,
      where: 'sync_status = ?',
      whereArgs: ['failed'],
    );
    return rows.map(PendingAnswerRecord.fromRow).toList();
  }

  Future<List<PendingAnswerRecord>> getFailedAnswers({
    required int sessionId,
  }) async {
    final db = await _db.open();
    final rows = await db.query(
      LocalDatabaseSchema.tableAnswers,
      where: 'session_id = ? AND sync_status = ?',
      whereArgs: [sessionId, 'failed'],
    );
    return rows.map(PendingAnswerRecord.fromRow).toList();
  }

  Future<void> retryFailedAnswer({
    required int sessionId,
    required int questionId,
  }) async {
    final db = await _db.open();
    await db.update(
      LocalDatabaseSchema.tableAnswers,
      {
        'sync_status': 'pending',
        'conflict_code': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'session_id = ? AND question_id = ?',
      whereArgs: [sessionId, questionId],
    );
  }

  Future<void> deletePendingAnswer({
    required int sessionId,
    required int questionId,
  }) async {
    final db = await _db.open();
    await db.delete(
      LocalDatabaseSchema.tableAnswers,
      where: 'session_id = ? AND question_id = ?',
      whereArgs: [sessionId, questionId],
    );
  }
}
