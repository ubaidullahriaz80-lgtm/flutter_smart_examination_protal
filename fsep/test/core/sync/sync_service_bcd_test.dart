import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/database/database_key_storage.dart';
import 'package:fsep/core/database/local_database_service.dart';
import 'package:fsep/core/sync/sync_service.dart';
import 'package:fsep/data/repositories/exam_session_repository.dart';
import 'package:fsep/data/repositories/local_behavior_event_repository.dart';
import 'package:fsep/data/repositories/pending_answer_repository.dart';

class _FixedKeyStorage extends DatabaseKeyStorage {
  _FixedKeyStorage(this.key);
  final String key;
  @override
  Future<String> getOrCreateKey() async => key;
}

class _FakeExamSessionRepository extends ExamSessionRepository {
  _FakeExamSessionRepository({this.bcdHandler});

  final Future<List<BehaviorSyncResultItem>> Function(
    int sessionId,
    List<LocalBehaviorEventRecord> events,
  )? bcdHandler;

  @override
  Future<List<BehaviorSyncResultItem>> syncBehaviorEvents({
    required int sessionId,
    required List<LocalBehaviorEventRecord> events,
  }) async {
    return bcdHandler!(sessionId, events);
  }
}

void main() {
  late Directory tempDir;
  late LocalDatabaseService dbService;
  late LocalBehaviorEventRepository localBcd;
  late PendingAnswerRepository pendingAnswers;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fsep_sync_service_bcd_test_');
    dbService = LocalDatabaseService(
      keyStorage: _FixedKeyStorage('h'.padRight(64, 'h')),
      testDbPath: '${tempDir.path}/test.db',
    );
    localBcd = LocalBehaviorEventRepository(databaseService: dbService);
    pendingAnswers = PendingAnswerRepository(databaseService: dbService);
  });

  tearDown(() async {
    await dbService.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('BCD events are discovered and synchronized', () async {
    await localBcd.saveEvent(sessionId: 100, eventType: 'focus_lost');

    var wasCalled = false;
    final fakeRepo = _FakeExamSessionRepository(
      bcdHandler: (sessionId, events) async {
        wasCalled = true;
        expect(sessionId, 100);
        expect(events, hasLength(1));
        return [
          BehaviorSyncResultItem(
            clientUuid: events.first.clientUuid,
            status: 'synced',
          )
        ];
      },
    );

    final sync = SyncService(
      examSessionRepository: fakeRepo,
      localBehaviorEventRepository: localBcd,
      pendingAnswerRepository: pendingAnswers,
    );

    await sync.syncPendingAnswers();

    expect(wasCalled, isTrue);
    expect(await localBcd.getEventsForSession(100), isEmpty);
  });

  test('Failed BCD sync (network error) leaves events in queue', () async {
    await localBcd.saveEvent(sessionId: 100, eventType: 'focus_lost');

    final fakeRepo = _FakeExamSessionRepository(
      bcdHandler: (sessionId, events) async {
        throw Exception('Network error');
      },
    );

    final sync = SyncService(
      examSessionRepository: fakeRepo,
      localBehaviorEventRepository: localBcd,
      pendingAnswerRepository: pendingAnswers,
    );

    await sync.syncPendingAnswers();

    expect(await localBcd.getEventsForSession(100), hasLength(1));
  });

  test('Poison-pill (CONFLICT_SESSION_CLOSED) purges BCD events from queue', () async {
    await localBcd.saveEvent(sessionId: 100, eventType: 'focus_lost');

    final fakeRepo = _FakeExamSessionRepository(
      bcdHandler: (sessionId, events) async {
        return [
          BehaviorSyncResultItem(
            clientUuid: events.first.clientUuid,
            status: 'conflict',
            code: 'CONFLICT_SESSION_CLOSED',
          )
        ];
      },
    );

    final sync = SyncService(
      examSessionRepository: fakeRepo,
      localBehaviorEventRepository: localBcd,
      pendingAnswerRepository: pendingAnswers,
    );

    await sync.syncPendingAnswers();

    // Purged because the session is closed and it can never be synced.
    expect(await localBcd.getEventsForSession(100), isEmpty);
  });
}
