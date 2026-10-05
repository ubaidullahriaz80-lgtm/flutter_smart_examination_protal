import '../../core/database/local_database_schema.dart';
import '../../core/database/local_database_service.dart';
import '../models/exam_session_model.dart';

/// Record representing a locally cached exam session.
class LocalSessionRecord {
  const LocalSessionRecord({
    required this.localId,
    this.serverSessionId,
    required this.examId,
    required this.status,
    required this.startedAt,
    this.expiresAt,
    this.submittedAt,
    required this.currentQuestionIndex,
    required this.serverClockOffsetMs,
    required this.createdAt,
    required this.updatedAt,
  });

  final int localId;
  final int? serverSessionId;
  final int examId;
  final String status;
  final DateTime startedAt;
  final DateTime? expiresAt;
  final DateTime? submittedAt;
  final int currentQuestionIndex;
  final int serverClockOffsetMs;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory LocalSessionRecord.fromRow(Map<String, dynamic> row) {
    return LocalSessionRecord(
      localId: row['local_id'] as int,
      serverSessionId: row['server_session_id'] as int?,
      examId: row['exam_id'] as int,
      status: row['status'] as String,
      startedAt: DateTime.parse(row['started_at'] as String),
      expiresAt: row['expires_at'] != null
          ? DateTime.parse(row['expires_at'] as String)
          : null,
      submittedAt: row['submitted_at'] != null
          ? DateTime.parse(row['submitted_at'] as String)
          : null,
      currentQuestionIndex: row['current_question_index'] as int,
      serverClockOffsetMs: row['server_clock_offset_ms'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Map<String, dynamic> toRow() {
    return {
      if (serverSessionId != null) 'server_session_id': serverSessionId,
      'exam_id': examId,
      'status': status,
      'started_at': startedAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
      'current_question_index': currentQuestionIndex,
      'server_clock_offset_ms': serverClockOffsetMs,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ExamSessionModel toModel(Map<int, String> answers) {
    if (serverSessionId == null) {
      throw StateError('Cannot convert local-only session to ExamSessionModel');
    }
    return ExamSessionModel(
      id: serverSessionId!,
      examId: examId,
      status: status,
      startedAt: startedAt,
      expiresAt: expiresAt ?? startedAt.add(const Duration(hours: 1)),
      serverTime:
          DateTime.now().add(Duration(milliseconds: serverClockOffsetMs)),
      answers: answers,
    );
  }
}

/// Local repository for persisting exam session state.
class LocalSessionRepository {
  LocalSessionRepository({LocalDatabaseService? databaseService})
      : _db = databaseService ?? LocalDatabaseService.instance;

  final LocalDatabaseService _db;

  Future<int> saveSession({
    int? serverSessionId,
    required int examId,
    required String status,
    required DateTime startedAt,
    DateTime? expiresAt,
    DateTime? submittedAt,
    int currentQuestionIndex = 0,
    int serverClockOffsetMs = 0,
  }) async {
    final now = DateTime.now().toIso8601String();

    return _db.transaction((txn) async {
      final existing = await txn.query(
        LocalDatabaseSchema.tableExamSessions,
        where: 'exam_id = ?',
        whereArgs: [examId],
        limit: 1,
      );

      if (existing.isEmpty) {
        return txn.insert(LocalDatabaseSchema.tableExamSessions, {
          'server_session_id': serverSessionId,
          'exam_id': examId,
          'status': status,
          'started_at': startedAt.toIso8601String(),
          'expires_at': expiresAt?.toIso8601String(),
          'submitted_at': submittedAt?.toIso8601String(),
          'current_question_index': currentQuestionIndex,
          'server_clock_offset_ms': serverClockOffsetMs,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        final localId = existing.first['local_id'] as int;
        await txn.update(
          LocalDatabaseSchema.tableExamSessions,
          {
            'server_session_id': serverSessionId,
            'status': status,
            'expires_at': expiresAt?.toIso8601String(),
            'submitted_at': submittedAt?.toIso8601String(),
            'current_question_index': currentQuestionIndex,
            'server_clock_offset_ms': serverClockOffsetMs,
            'updated_at': now,
          },
          where: 'local_id = ?',
          whereArgs: [localId],
        );
        return localId;
      }
    });
  }

  Future<LocalSessionRecord?> getSessionByLocalId(int localId) async {
    final db = await _db.open();
    final rows = await db.query(
      LocalDatabaseSchema.tableExamSessions,
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    return rows.isEmpty ? null : LocalSessionRecord.fromRow(rows.first);
  }

  Future<LocalSessionRecord?> getSessionByServerId(int serverSessionId) async {
    final db = await _db.open();
    final rows = await db.query(
      LocalDatabaseSchema.tableExamSessions,
      where: 'server_session_id = ?',
      whereArgs: [serverSessionId],
      limit: 1,
    );
    return rows.isEmpty ? null : LocalSessionRecord.fromRow(rows.first);
  }

  Future<LocalSessionRecord?> getSessionByExamId(int examId) async {
    final db = await _db.open();
    final rows = await db.query(
      LocalDatabaseSchema.tableExamSessions,
      where: 'exam_id = ?',
      whereArgs: [examId],
      limit: 1,
    );
    return rows.isEmpty ? null : LocalSessionRecord.fromRow(rows.first);
  }

  Future<void> updateQuestionIndex({
    required int localId,
    required int questionIndex,
  }) async {
    final db = await _db.open();
    await db.update(
      LocalDatabaseSchema.tableExamSessions,
      {
        'current_question_index': questionIndex,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> updateServerClockOffset({
    required int localId,
    required int offsetMs,
  }) async {
    final db = await _db.open();
    await db.update(
      LocalDatabaseSchema.tableExamSessions,
      {
        'server_clock_offset_ms': offsetMs,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> updateSessionStatus({
    required int localId,
    required String status,
  }) async {
    final db = await _db.open();
    await db.update(
      LocalDatabaseSchema.tableExamSessions,
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> updateExpiresAt({
    required int localId,
    required String? expiresAt,
  }) async {
    final db = await _db.open();
    await db.update(
      LocalDatabaseSchema.tableExamSessions,
      {
        'expires_at': expiresAt,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> updateSubmittedAt({
    required int localId,
    required String? submittedAt,
  }) async {
    final db = await _db.open();
    await db.update(
      LocalDatabaseSchema.tableExamSessions,
      {
        'submitted_at': submittedAt,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> deleteSession(int localId) async {
    final db = await _db.open();
    await db.delete(
      LocalDatabaseSchema.tableExamSessions,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }
}
