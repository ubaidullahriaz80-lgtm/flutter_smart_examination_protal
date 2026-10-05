import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/database/database_key_storage.dart';
import 'package:fsep/core/database/local_database_service.dart';
import 'package:fsep/data/repositories/pending_answer_repository.dart';

/// Same in-memory key-storage double used across the Phase A/B suites —
/// avoids touching the real flutter_secure_storage platform channel.
class _FixedKeyStorage extends DatabaseKeyStorage {
  _FixedKeyStorage(this.key);
  final String key;

  @override
  Future<String> getOrCreateKey() async => key;
}

void main() {
  late Directory tempDir;
  late LocalDatabaseService dbService;
  late PendingAnswerRepository repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fsep_pending_answer_test_');
    dbService = LocalDatabaseService(
      keyStorage: _FixedKeyStorage('d'.padRight(64, 'd')),
      testDbPath: '${tempDir.path}/test.db',
    );
    repository = PendingAnswerRepository(databaseService: dbService);
  });

  tearDown(() async {
    await dbService.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Test 1 — a pending answer can be inserted', () async {
    await repository.savePendingAnswer(
      sessionId: 1,
      questionId: 11,
      selectedOption: 'B',
    );

    final record = await repository.getPendingAnswer(
      sessionId: 1,
      questionId: 11,
    );
    expect(record, isNotNull);
  });

  test('Test 2 — the answer can be retrieved', () async {
    await repository.savePendingAnswer(
      sessionId: 1,
      questionId: 11,
      selectedOption: 'B',
    );

    final record = await repository.getPendingAnswer(
      sessionId: 1,
      questionId: 11,
    );
    expect(record!.selectedOption, 'B');
  });

  test('Test 3 — session id is preserved', () async {
    await repository.savePendingAnswer(
      sessionId: 42,
      questionId: 11,
      selectedOption: 'B',
    );

    final record = await repository.getPendingAnswer(
      sessionId: 42,
      questionId: 11,
    );
    expect(record!.sessionId, 42);
  });

  test('Test 4 — question id is preserved', () async {
    await repository.savePendingAnswer(
      sessionId: 1,
      questionId: 99,
      selectedOption: 'B',
    );

    final record = await repository.getPendingAnswer(
      sessionId: 1,
      questionId: 99,
    );
    expect(record!.questionId, 99);
  });

  test('Test 5 — the exact answer payload is preserved', () async {
    // A matching question's answer is itself JSON — the queue must not
    // mangle it, exactly as the real online payload (selected_option)
    // never does.
    const payload = '{"CPU":"Executes instructions","RAM":"Temporary memory"}';
    await repository.savePendingAnswer(
      sessionId: 1,
      questionId: 11,
      selectedOption: payload,
    );

    final record = await repository.getPendingAnswer(
      sessionId: 1,
      questionId: 11,
    );
    expect(record!.selectedOption, payload);
  });

  test('Test 6 — timestamp and status are persisted', () async {
    final before = DateTime.now();
    await repository.savePendingAnswer(
      sessionId: 1,
      questionId: 11,
      selectedOption: 'B',
    );
    final after = DateTime.now();

    final record = await repository.getPendingAnswer(
      sessionId: 1,
      questionId: 11,
    );
    expect(record!.syncStatus, 'pending');
    expect(
      record.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
      isTrue,
    );
    expect(
      record.createdAt.isBefore(after.add(const Duration(seconds: 1))),
      isTrue,
    );
    expect(record.updatedAt, record.createdAt);
  });

  test(
    'Test 7 — a second answer for the same session/question updates the '
    'pending answer rather than creating a duplicate',
    () async {
      await repository.savePendingAnswer(
        sessionId: 1,
        questionId: 11,
        selectedOption: 'A',
      );
      final first = await repository.getPendingAnswer(
        sessionId: 1,
        questionId: 11,
      );

      // Ensure a measurable time gap so updated_at can actually differ.
      await Future<void>.delayed(const Duration(milliseconds: 5));

      await repository.savePendingAnswer(
        sessionId: 1,
        questionId: 11,
        selectedOption: 'C',
      );

      final all = await repository.getPendingAnswers(sessionId: 1);
      expect(all, hasLength(1)); // still exactly one row, not two

      final second = await repository.getPendingAnswer(
        sessionId: 1,
        questionId: 11,
      );
      expect(second!.selectedOption, 'C');
      expect(second.localId, first!.localId); // same row, updated in place
      expect(second.createdAt, first.createdAt); // created_at preserved
      expect(
        second.updatedAt.isAfter(first.updatedAt) ||
            second.updatedAt.isAtSameMomentAs(first.updatedAt),
        isTrue,
      );
    },
  );

  test(
    'Test 8 — multiple questions in the same session can coexist',
    () async {
      await repository.savePendingAnswer(
        sessionId: 1,
        questionId: 11,
        selectedOption: 'A',
      );
      await repository.savePendingAnswer(
        sessionId: 1,
        questionId: 12,
        selectedOption: 'True',
      );
      await repository.savePendingAnswer(
        sessionId: 1,
        questionId: 13,
        selectedOption: 'Graphics Processing Unit',
      );

      final all = await repository.getPendingAnswers(sessionId: 1);
      expect(all, hasLength(3));
      expect(
        all.map((r) => r.questionId).toSet(),
        {11, 12, 13},
      );
    },
  );

  test(
    'Test 9 — pending answers survive closing and reopening the database',
    () async {
      await repository.savePendingAnswer(
        sessionId: 1,
        questionId: 11,
        selectedOption: 'B',
      );
      await dbService.close();

      final reopened = LocalDatabaseService(
        keyStorage: _FixedKeyStorage('d'.padRight(64, 'd')),
        testDbPath: '${tempDir.path}/test.db',
      );
      final repositoryAfterReopen =
          PendingAnswerRepository(databaseService: reopened);

      final record = await repositoryAfterReopen.getPendingAnswer(
        sessionId: 1,
        questionId: 11,
      );
      expect(record, isNotNull);
      expect(record!.selectedOption, 'B');

      await reopened.close();
    },
  );

  test('Test 10 — a pending answer can be deleted cleanly', () async {
    await repository.savePendingAnswer(
      sessionId: 1,
      questionId: 11,
      selectedOption: 'B',
    );
    expect(
      await repository.getPendingAnswer(sessionId: 1, questionId: 11),
      isNotNull,
    );

    await repository.deletePendingAnswer(sessionId: 1, questionId: 11);

    expect(
      await repository.getPendingAnswer(sessionId: 1, questionId: 11),
      isNull,
    );
    expect(await repository.getPendingAnswers(sessionId: 1), isEmpty);
  });

  test(
    'Test 11 — marking an answer synced removes it from the pending list '
    'without deleting the row',
    () async {
      await repository.savePendingAnswer(
        sessionId: 1,
        questionId: 11,
        selectedOption: 'B',
      );

      await repository.markSynced(sessionId: 1, questionId: 11);

      // No longer "pending"...
      expect(await repository.getPendingAnswers(sessionId: 1), isEmpty);

      // ...but the row itself still exists, now marked synced.
      final db = await dbService.open();
      final rows = await db.query(
        'local_answers',
        where: 'session_id = ? AND question_id = ?',
        whereArgs: [1, 11],
      );
      expect(rows, hasLength(1));
      expect(rows.first['sync_status'], 'synced');
      expect(rows.first['last_synced_at'], isNotNull);
    },
  );

  test(
    'Test 12 — pending session ids are discovered across multiple sessions',
    () async {
      await repository.savePendingAnswer(
        sessionId: 1,
        questionId: 11,
        selectedOption: 'A',
      );
      await repository.savePendingAnswer(
        sessionId: 2,
        questionId: 21,
        selectedOption: 'B',
      );

      expect(
        (await repository.getPendingSessionIds()).toSet(),
        {1, 2},
      );

      // A session with everything already synced must drop out of the
      // discovery list.
      await repository.markSynced(sessionId: 1, questionId: 11);

      expect(
        (await repository.getPendingSessionIds()).toSet(),
        {2},
      );
    },
  );

  test('Test 13 — all failed answers can be retrieved at once', () async {
    await repository.savePendingAnswer(
      sessionId: 1,
      questionId: 11,
      selectedOption: 'A',
    );
    await repository.savePendingAnswer(
      sessionId: 2,
      questionId: 21,
      selectedOption: 'B',
    );

    // One conflict in session 1...
    await repository.markConflict(
      sessionId: 1,
      questionId: 11,
      conflictCode: 'CONFLICT_SESSION_CLOSED',
    );

    // ...and one in session 2.
    await repository.markConflict(
      sessionId: 2,
      questionId: 21,
      conflictCode: 'SERVER_VERSION_AHEAD',
    );

    final allFailed = await repository.getAllFailedAnswers();
    expect(allFailed, hasLength(2));
    expect(
      allFailed.map((r) => r.conflictCode).toSet(),
      {'CONFLICT_SESSION_CLOSED', 'SERVER_VERSION_AHEAD'},
    );
  });
}
