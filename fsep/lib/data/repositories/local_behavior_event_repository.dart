import 'dart:convert';
import 'dart:math';

import '../../core/database/local_database_service.dart';

/// Record representing a locally queued behavioral event.
class LocalBehaviorEventRecord {
  const LocalBehaviorEventRecord({
    required this.localId,
    required this.clientUuid,
    required this.sessionId,
    required this.eventType,
    this.metadata,
    required this.createdAt,
  });

  final int localId;
  final String clientUuid;
  final int sessionId;
  final String eventType;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  factory LocalBehaviorEventRecord.fromRow(Map<String, dynamic> row) {
    final metadataJson = row['metadata'] as String?;
    return LocalBehaviorEventRecord(
      localId: row['local_id'] as int,
      clientUuid: row['client_uuid'] as String,
      sessionId: row['session_id'] as int,
      eventType: row['event_type'] as String,
      metadata: metadataJson != null
          ? jsonDecode(metadataJson) as Map<String, dynamic>
          : null,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

/// Local repository for queuing behavioral events while offline.
class LocalBehaviorEventRepository {
  LocalBehaviorEventRepository({LocalDatabaseService? databaseService})
      : _db = databaseService ?? LocalDatabaseService.instance;

  final LocalDatabaseService _db;

  Future<void> saveEvent({
    required int sessionId,
    required String eventType,
    Map<String, dynamic>? metadata,
  }) async {
    await _db.insertBehaviorEvent({
      'client_uuid': _generateUuid(),
      'session_id': sessionId,
      'event_type': eventType,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  String _generateUuid() {
    final random = Random.secure();
    final hex = List.generate(32, (_) => random.nextInt(16).toRadixString(16));
    return hex.join();
  }

  Future<List<LocalBehaviorEventRecord>> getEventsForSession(
    int sessionId,
  ) async {
    final rows = await _db.getBehaviorEventsForSession(sessionId);
    return rows.map(LocalBehaviorEventRecord.fromRow).toList();
  }

  Future<List<LocalBehaviorEventRecord>> getAllPendingEvents() async {
    final rows = await _db.getAllPendingBehaviorEvents();
    return rows.map(LocalBehaviorEventRecord.fromRow).toList();
  }

  Future<void> deleteEvent(int localId) async {
    await _db.deleteBehaviorEvent(localId);
  }
}
