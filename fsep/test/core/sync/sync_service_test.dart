import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/connectivity/connectivity_service.dart';
import 'package:fsep/core/database/database_key_storage.dart';
import 'package:fsep/core/database/local_database_service.dart';
import 'package:fsep/core/sync/sync_service.dart';
import 'package:fsep/data/repositories/exam_session_repository.dart';
import 'package:fsep/data/repositories/pending_answer_repository.dart';

/// Same in-memory key-storage double used across the Phase A/B/C suites.
class _FixedKeyStorage extends DatabaseKeyStorage {
  _FixedKeyStorage(this.key);
  final String key;

  @override
  Future<String> getOrCreateKey() async => key;
}

/// Same deterministic fake used in the Phase D suite
/// (test/core/connectivity/connectivity_service_test.dart) — never
/// touches the real connectivity_plus platform channel.
class _FakeConnectivitySource implements ConnectivitySource {
  _FakeConnectivitySource({this.initialOnline = true});

  final bool initialOnline;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> checkIsOnline() async => initialOnline;

  @override
  Stream<bool> get onRawChange => _controller.stream;

  void emit(bool online) => _controller.add(online);

  Future<void> disposeFake() => _controller.close();
}

/// Fakes only the HTTP call inside ExamSessionRepository.syncAnswers —
/// same "subclass and override" test-double convention used throughout
/// this suite (see _ThrowingExamCacheRepository in
/// local_exam_cache_repository_test.dart). [handler] decides the
/// per-request result and [callLog] records every invocation, so tests
/// can assert exactly how many times (and with what) the batch endpoint
/// would have been called.
class _FakeExamSessionRepository extends ExamSessionRepository {
  _FakeExamSessionRepository(this.handler);

  final Future<List<AnswerSyncResultItem>> Function(
    int sessionId,
    List<PendingAnswerRecord> answers,
  ) handler;

  final List<int> callLog = [];

  @override
  Future<List<AnswerSyncResultItem>> syncAnswers({
    required int sessionId,
    required List<PendingAnswerRecord> answers,
  }) async {
    callLog.add(sessionId);
    return handler(sessionId, answers);
  }
}

void main() {
  late Directory tempDir;
  late LocalDatabaseService dbService;
  late PendingAnswerRepository pendingAnswers;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fsep_sync_service_test_');
    dbService = LocalDatabaseService(
      keyStorage: _FixedKeyStorage('f'.padRight(64, 'f')),
      testDbPath: '${tempDir.path}/test.db',
    );
    pendingAnswers = PendingAnswerRepository(databaseService: dbService);
  });

  tearDown(() async {
    await dbService.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Test 1 — pending local answers are discovered', () async {
    await pendingAnswers.savePendingAnswer(
      sessionId: 1,
      questionId: 11,
      selectedOption: 'B',
    );

    var wasCalled = false;
    final fakeExamSessionRepo = _FakeExamSessionRepository((sessionId, answers) async {
      wasCalled = true;
      expect(sessionId, 1);
      expect(answers, hasLength(1));
      expect(answers.single.questionId, 11);
      return [const AnswerSyncResultItem(questionId: 11, status: 'synced')];
    });

    final sync = SyncService(
      pendingAnswerRepository: pendingAnswers,
      examSessionRepository: fakeExamSessionRepo,
    );

    await sync.syncPendingAnswers();

    expect(wasCalled, isTrue);
  });

  test(
    'Test 2 — successful backend synchronization marks the local row '
    'synchronized',
    () async {
      await pendingAnswers.savePendingAnswer(
        sessionId: 1,
        questionId: 11,
        selectedOption: 'B',
      );

      final fakeExamSessionRepo = _FakeExamSessionRepository((sessionId, answers) async {
        return [const AnswerSyncResultItem(questionId: 11, status: 'synced')];
      });

      final sync = SyncService(
        pendingAnswerRepository: pendingAnswers,
        examSessionRepository: fakeExamSessionRepo,
      );

      await sync.syncPendingAnswers();

      // No longer discoverable as pending...
      expect(await pendingAnswers.getPendingAnswers(sessionId: 1), isEmpty);
      // ...and no longer shows up for a second sync run either.
      expect(await pendingAnswers.getPendingSessionIds(), isEmpty);
    },
  );

  test(
    'Test 3 — failed synchronization leaves the local row pending',
    () async {
      await pendingAnswers.savePendingAnswer(
        sessionId: 1,
        questionId: 11,
        selectedOption: 'B',
      );

      final fakeExamSessionRepo = _FakeExamSessionRepository((sessionId, answers) async {
        return [
          const AnswerSyncResultItem(
            questionId: 11,
            status: 'error',
            message: 'This exam session has expired.',
          ),
        ];
      });

      final sync = SyncService(
        pendingAnswerRepository: pendingAnswers,
        examSessionRepository: fakeExamSessionRepo,
      );

      await sync.syncPendingAnswers();

      final record = await pendingAnswers.getPendingAnswer(
        sessionId: 1,
        questionId: 11,
      );
      expect(record, isNotNull);
      expect(record!.syncStatus, 'pending'); // unchanged
    },
  );

  test(
    'Test 3b — a batch request that throws entirely also leaves every '
    'queued row pending',
    () async {
      await pendingAnswers.savePendingAnswer(
        sessionId: 1,
        questionId: 11,
        selectedOption: 'B',
      );

      final fakeExamSessionRepo = _FakeExamSessionRepository((sessionId, answers) async {
        throw StateError('simulated network failure mid-sync');
      });

      final sync = SyncService(
        pendingAnswerRepository: pendingAnswers,
        examSessionRepository: fakeExamSessionRepo,
      );

      // Must not throw out of syncPendingAnswers() itself.
      await sync.syncPendingAnswers();

      final record = await pendingAnswers.getPendingAnswer(
        sessionId: 1,
        questionId: 11,
      );
      expect(record!.syncStatus, 'pending');
    },
  );

  test(
    'Test 4 — a duplicate sync invocation does not run concurrently',
    () async {
      await pendingAnswers.savePendingAnswer(
        sessionId: 1,
        questionId: 11,
        selectedOption: 'B',
      );

      final firstCallStarted = Completer<void>();
      final releaseFirstCall = Completer<void>();

      final fakeExamSessionRepo = _FakeExamSessionRepository((sessionId, answers) async {
        firstCallStarted.complete();
        await releaseFirstCall.future; // block until the test releases it
        return [const AnswerSyncResultItem(questionId: 11, status: 'synced')];
      });

      final sync = SyncService(
        pendingAnswerRepository: pendingAnswers,
        examSessionRepository: fakeExamSessionRepo,
      );

      final firstRun = sync.syncPendingAnswers();
      await firstCallStarted.future; // first run is now mid-flight

      expect(sync.isSyncing, isTrue);

      // Second call while the first is still in progress must be a
      // no-op, not a second overlapping batch request.
      await sync.syncPendingAnswers();
      expect(fakeExamSessionRepo.callLog, hasLength(1));

      releaseFirstCall.complete();
      await firstRun;

      expect(sync.isSyncing, isFalse);
    },
  );

  test('Test 5 — an online transition triggers synchronization', () async {
    await pendingAnswers.savePendingAnswer(
      sessionId: 1,
      questionId: 11,
      selectedOption: 'B',
    );

    var syncCalls = 0;
    final fakeExamSessionRepo = _FakeExamSessionRepository((sessionId, answers) async {
      syncCalls++;
      return [const AnswerSyncResultItem(questionId: 11, status: 'synced')];
    });

    final connectivitySource = _FakeConnectivitySource(initialOnline: false);
    final connectivity = ConnectivityService(source: connectivitySource);
    await connectivity.start();

    final sync = SyncService(
      pendingAnswerRepository: pendingAnswers,
      examSessionRepository: fakeExamSessionRepo,
      connectivityService: connectivity,
    );
    sync.startListening();

    expect(syncCalls, 0); // nothing yet — still offline

    connectivitySource.emit(true); // offline -> online
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(syncCalls, 1);
    expect(await pendingAnswers.getPendingAnswers(sessionId: 1), isEmpty);

    await sync.dispose();
    await connectivity.dispose();
    await connectivitySource.disposeFake();
  });

  test(
    'Test 6 — syncing does not touch a session that has no pending '
    'answers (the online answer path is left alone)',
    () async {
      await pendingAnswers.savePendingAnswer(
        sessionId: 1,
        questionId: 11,
        selectedOption: 'B',
      );
      // session 2 has never had a failed save — nothing queued for it.

      final fakeExamSessionRepo = _FakeExamSessionRepository((sessionId, answers) async {
        return [
          AnswerSyncResultItem(questionId: answers.first.questionId, status: 'synced'),
        ];
      });

      final sync = SyncService(
        pendingAnswerRepository: pendingAnswers,
        examSessionRepository: fakeExamSessionRepo,
      );

      await sync.syncPendingAnswers();

      // Only the session that actually had a queued answer was ever
      // touched.
      expect(fakeExamSessionRepo.callLog, [1]);
    },
  );
}
