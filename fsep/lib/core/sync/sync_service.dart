import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import '../../data/repositories/exam_session_repository.dart';
import '../../data/repositories/local_behavior_event_repository.dart';
import '../../data/repositories/pending_answer_repository.dart';
import '../connectivity/connectivity_service.dart';
import '../notifications/local_notification_service.dart';

/// Background synchronization service for offlined answers and behavior events.
class SyncService {
  SyncService({
    PendingAnswerRepository? pendingAnswerRepository,
    ExamSessionRepository? examSessionRepository,
    LocalBehaviorEventRepository? localBehaviorEventRepository,
    ConnectivityService? connectivityService,
  })  : _pendingAnswers = pendingAnswerRepository ?? PendingAnswerRepository(),
        _examSessionRepository =
            examSessionRepository ?? ExamSessionRepository(),
        _localBehaviorEvents =
            localBehaviorEventRepository ?? LocalBehaviorEventRepository(),
        _connectivity = connectivityService;

  final PendingAnswerRepository _pendingAnswers;
  final ExamSessionRepository _examSessionRepository;
  final LocalBehaviorEventRepository _localBehaviorEvents;
  final ConnectivityService? _connectivity;

  StreamSubscription<NetworkStatus>? _connectivitySubscription;
  Timer? _backoffTimer;
  int _retryCount = 0;

  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  void startListening() {
    _connectivitySubscription ??=
        _connectivity?.onStatusChange.listen((status) {
      if (status == NetworkStatus.online) {
        unawaited(syncPendingAnswers());
      }
    });
  }

  Future<void> stopListening() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  Future<void> syncPendingAnswers() async {
    if (_isSyncing) {
      return;
    }
    _isSyncing = true;
    _backoffTimer?.cancel();

    int totalSynced = 0;
    bool hadFatalError = false;

    try {
      final answerSessionIds = await _pendingAnswers.getPendingSessionIds();
      final allPendingBcd = await _localBehaviorEvents.getAllPendingEvents();
      final bcdSessionIds = allPendingBcd.map((e) => e.sessionId).toSet();

      final allSessionIds = answerSessionIds.toSet().union(bcdSessionIds);

      for (final sessionId in allSessionIds) {
        final result = await _syncSession(sessionId);
        totalSynced += result['synced'] as int;
        if (result['fatal'] == true) {
          hadFatalError = true;
        }
      }

      if (totalSynced > 0) {
        LocalNotificationService.showNotification(
          id: 100,
          title: 'Sync Complete',
          body: 'Your offline data has been successfully synchronized.',
        );
      }

      if (!hadFatalError) {
        _retryCount = 0;
      } else {
        _scheduleRetry();
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('SyncService: sync run failed: $error\n$stackTrace');
      }
      _scheduleRetry();
    } finally {
      _isSyncing = false;
    }
  }

  void _scheduleRetry() {
    if (_retryCount >= 5) {
      if (kDebugMode) {
        debugPrint('SyncService: reached max retry attempts (5). Stopping.');
      }
      return;
    }

    _retryCount++;
    final delay = Duration(seconds: 1 << (_retryCount - 1));
    if (kDebugMode) {
      debugPrint('SyncService: scheduling retry #$_retryCount in ${delay.inSeconds}s');
    }
    _backoffTimer = Timer(delay, syncPendingAnswers);
  }

  Future<Map<String, dynamic>> _syncSession(int sessionId) async {
    int synced = 0;
    bool fatal = false;

    final answerResult = await _syncSessionAnswers(sessionId);
    synced += answerResult['synced'] as int;
    if (answerResult['fatal'] == true) fatal = true;

    final bcdResult = await _syncSessionBehaviorEvents(sessionId);
    synced += bcdResult['synced'] as int;
    if (bcdResult['fatal'] == true) fatal = true;

    return {'synced': synced, 'fatal': fatal};
  }

  Future<Map<String, dynamic>> _syncSessionAnswers(int sessionId) async {
    final pending =
        await _pendingAnswers.getPendingAnswers(sessionId: sessionId);
    if (pending.isEmpty) {
      return {'synced': 0, 'fatal': false};
    }

    int syncedCount = 0;
    final List<AnswerSyncResultItem> results;
    try {
      results = await _examSessionRepository.syncAnswers(
        sessionId: sessionId,
        answers: pending,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'SyncService: answer batch sync failed for session $sessionId: $error',
        );
      }
      return {'synced': 0, 'fatal': true};
    }

    for (final result in results) {
      if (result.isSynced) {
        syncedCount++;
        await _pendingAnswers.markSynced(
          sessionId: sessionId,
          questionId: result.questionId,
        );
      } else if (result.isConflict) {
        await _pendingAnswers.markConflict(
          sessionId: sessionId,
          questionId: result.questionId,
          conflictCode: result.code ?? 'UNKNOWN_CONFLICT',
        );
      }
    }
    return {'synced': syncedCount, 'fatal': false};
  }

  Future<Map<String, dynamic>> _syncSessionBehaviorEvents(int sessionId) async {
    final pending =
        await _localBehaviorEvents.getEventsForSession(sessionId);
    if (pending.isEmpty) {
      return {'synced': 0, 'fatal': false};
    }

    int syncedCount = 0;
    final List<BehaviorSyncResultItem> results;
    try {
      results = await _examSessionRepository.syncBehaviorEvents(
        sessionId: sessionId,
        events: pending,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'SyncService: BCD batch sync failed for session $sessionId: $error',
        );
      }
      return {'synced': 0, 'fatal': true};
    }

    for (final result in results) {
      if (result.isSynced) {
        syncedCount++;
        final record = pending.firstWhere((e) => e.clientUuid == result.clientUuid);
        await _localBehaviorEvents.deleteEvent(record.localId);
      } else if (result.isConflict && result.code == 'CONFLICT_SESSION_CLOSED') {
        final record = pending.firstWhere((e) => e.clientUuid == result.clientUuid);
        await _localBehaviorEvents.deleteEvent(record.localId);
      }
    }
    return {'synced': syncedCount, 'fatal': false};
  }

  Future<void> retryFailedSync({
    required int sessionId,
    required int questionId,
  }) async {
    await _pendingAnswers.retryFailedAnswer(
      sessionId: sessionId,
      questionId: questionId,
    );
    await syncPendingAnswers();
  }

  Future<void> purgeFailedAnswer({
    required int sessionId,
    required int questionId,
  }) {
    return _pendingAnswers.deletePendingAnswer(
      sessionId: sessionId,
      questionId: questionId,
    );
  }

  Future<void> dispose() async {
    _backoffTimer?.cancel();
    await stopListening();
  }
}
