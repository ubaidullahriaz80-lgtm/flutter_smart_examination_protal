import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/database/database_key_storage.dart';
import 'package:fsep/core/database/local_database_service.dart';
import 'package:fsep/data/repositories/local_session_repository.dart';

class _FixedKeyStorage extends DatabaseKeyStorage {
  _FixedKeyStorage(this.key);
  final String key;

  @override
  Future<String> getOrCreateKey() async => key;
}

void main() {
  late Directory tempDir;
  late LocalDatabaseService dbService;
  late LocalSessionRepository repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fsep_local_session_test_');
    dbService = LocalDatabaseService(
      keyStorage: _FixedKeyStorage('s'.padRight(64, 's')),
      testDbPath: '${tempDir.path}/test.db',
    );
    repository = LocalSessionRepository(databaseService: dbService);
  });

  tearDown(() async {
    await dbService.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Test 1 — a local session can be saved and retrieved by local ID', () async {
    final startedAt = DateTime.now();
    final localId = await repository.saveSession(
      examId: 1,
      status: 'in_progress',
      startedAt: startedAt,
    );

    final session = await repository.getSessionByLocalId(localId);
    expect(session, isNotNull);
    expect(session!.examId, 1);
    expect(session.status, 'in_progress');
    // SQLite stores ISO8601 strings, so precision might slightly differ on parse back,
    // but the core value should be the same.
    expect(session.startedAt.toIso8601String(), startedAt.toIso8601String());
  });

  test('Test 2 — session can be retrieved by server session ID', () async {
    await repository.saveSession(
      serverSessionId: 123,
      examId: 1,
      status: 'in_progress',
      startedAt: DateTime.now(),
    );

    final session = await repository.getSessionByServerId(123);
    expect(session, isNotNull);
    expect(session!.serverSessionId, 123);
    expect(session.examId, 1);
  });

  test('Test 3 — updating question index works', () async {
    final localId = await repository.saveSession(
      examId: 1,
      status: 'in_progress',
      startedAt: DateTime.now(),
    );

    await repository.updateQuestionIndex(localId: localId, questionIndex: 5);

    final session = await repository.getSessionByLocalId(localId);
    expect(session!.currentQuestionIndex, 5);
  });

  test('Test 4 — updating server clock offset works', () async {
    final localId = await repository.saveSession(
      examId: 1,
      status: 'in_progress',
      startedAt: DateTime.now(),
    );

    await repository.updateServerClockOffset(localId: localId, offsetMs: 1000);

    final session = await repository.getSessionByLocalId(localId);
    expect(session!.serverClockOffsetMs, 1000);
  });

  test('Test 5 — updating session status works', () async {
    final localId = await repository.saveSession(
      examId: 1,
      status: 'in_progress',
      startedAt: DateTime.now(),
    );

    await repository.updateSessionStatus(localId: localId, status: 'submitted');

    final session = await repository.getSessionByLocalId(localId);
    expect(session!.status, 'submitted');
  });

  test('Test 6 — updating expires_at works', () async {
    final localId = await repository.saveSession(
      examId: 1,
      status: 'in_progress',
      startedAt: DateTime.now(),
    );

    final expiresAt = DateTime.now().add(const Duration(hours: 1)).toIso8601String();
    await repository.updateExpiresAt(localId: localId, expiresAt: expiresAt);

    final session = await repository.getSessionByLocalId(localId);
    expect(session!.expiresAt?.toIso8601String(), expiresAt);
  });

  test('Test 7 — updating submitted_at works', () async {
    final localId = await repository.saveSession(
      examId: 1,
      status: 'in_progress',
      startedAt: DateTime.now(),
    );

    final submittedAt = DateTime.now().toIso8601String();
    await repository.updateSubmittedAt(localId: localId, submittedAt: submittedAt);

    final session = await repository.getSessionByLocalId(localId);
    expect(session!.submittedAt?.toIso8601String(), submittedAt);
  });

  test('Test 8 — a session can be deleted', () async {
    final localId = await repository.saveSession(
      examId: 1,
      status: 'in_progress',
      startedAt: DateTime.now(),
    );
    expect(await repository.getSessionByLocalId(localId), isNotNull);

    await repository.deleteSession(localId);

    expect(await repository.getSessionByLocalId(localId), isNull);
  });

  test('Test 9 — saveSession updates existing session for same examId', () async {
    final firstId = await repository.saveSession(
      examId: 1,
      status: 'in_progress',
      startedAt: DateTime.now(),
    );

    final secondId = await repository.saveSession(
      examId: 1,
      status: 'submitted',
      startedAt: DateTime.now(),
    );

    expect(secondId, firstId);
    final session = await repository.getSessionByLocalId(firstId);
    expect(session!.status, 'submitted');
  });
}
