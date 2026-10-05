import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/database/database_key_storage.dart';
import 'package:fsep/core/database/local_database_service.dart';
import 'package:fsep/data/repositories/local_behavior_event_repository.dart';

class _FixedKeyStorage extends DatabaseKeyStorage {
  _FixedKeyStorage(this.key);
  final String key;
  @override
  Future<String> getOrCreateKey() async => key;
}

void main() {
  late Directory tempDir;
  late LocalDatabaseService dbService;
  late LocalBehaviorEventRepository repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fsep_local_bcd_test_');
    dbService = LocalDatabaseService(
      keyStorage: _FixedKeyStorage('b'.padRight(64, 'b')),
      testDbPath: '${tempDir.path}/test.db',
    );
    repository = LocalBehaviorEventRepository(databaseService: dbService);
  });

  tearDown(() async {
    await dbService.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Test A/B — Save and retrieve behavior event', () async {
    await repository.saveEvent(
      sessionId: 100,
      eventType: 'focus_lost',
      metadata: {'reason': 'tab_switch'},
    );

    final events = await repository.getEventsForSession(100);
    expect(events, hasLength(1));
    expect(events.first.eventType, 'focus_lost');
    expect(events.first.metadata?['reason'], 'tab_switch');
    expect(events.first.sessionId, 100);
  });

  test('Test C — Save multiple events for a session', () async {
    await repository.saveEvent(sessionId: 100, eventType: 'focus_lost');
    await repository.saveEvent(sessionId: 100, eventType: 'focus_regained');

    final events = await repository.getEventsForSession(100);
    expect(events, hasLength(2));
    expect(events[0].eventType, 'focus_lost');
    expect(events[1].eventType, 'focus_regained');
  });

  test('Test D — Events belonging to different sessions remain separated', () async {
    await repository.saveEvent(sessionId: 100, eventType: 'focus_lost');
    await repository.saveEvent(sessionId: 200, eventType: 'navigation_away');

    final session100 = await repository.getEventsForSession(100);
    final session200 = await repository.getEventsForSession(200);

    expect(session100, hasLength(1));
    expect(session100.first.eventType, 'focus_lost');

    expect(session200, hasLength(1));
    expect(session200.first.eventType, 'navigation_away');
  });

  test('Test E — Events survive database close/reopen', () async {
    await repository.saveEvent(sessionId: 100, eventType: 'focus_lost');
    await dbService.close();

    final reopened = LocalDatabaseService(
      keyStorage: _FixedKeyStorage('b'.padRight(64, 'b')),
      testDbPath: '${tempDir.path}/test.db',
    );
    final repoAfterReopen = LocalBehaviorEventRepository(databaseService: reopened);

    final events = await repoAfterReopen.getEventsForSession(100);
    expect(events, hasLength(1));
    expect(events.first.eventType, 'focus_lost');

    await reopened.close();
  });

  test('Test F — Delete/remove an event works correctly', () async {
    await repository.saveEvent(sessionId: 100, eventType: 'focus_lost');
    final eventsBefore = await repository.getEventsForSession(100);
    final localId = eventsBefore.first.localId;

    await repository.deleteEvent(localId);

    final eventsAfter = await repository.getEventsForSession(100);
    expect(eventsAfter, isEmpty);
  });

  test('Test — Get all pending events across all sessions', () async {
    await repository.saveEvent(sessionId: 100, eventType: 'focus_lost');
    await repository.saveEvent(sessionId: 200, eventType: 'focus_lost');

    final allPending = await repository.getAllPendingEvents();
    expect(allPending, hasLength(2));
    expect(allPending.map((e) => e.sessionId).toSet(), {100, 200});
  });
}
