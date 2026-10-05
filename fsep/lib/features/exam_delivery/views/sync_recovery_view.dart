import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/database/local_database_service.dart';
import '../../../core/sync/sync_service.dart';
import '../../../data/repositories/local_exam_cache_repository.dart';
import '../../../data/repositories/pending_answer_repository.dart';

class SyncRecoveryView extends StatefulWidget {
  const SyncRecoveryView({super.key});

  @override
  State<SyncRecoveryView> createState() => _SyncRecoveryViewState();
}

class _SyncRecoveryViewState extends State<SyncRecoveryView> {
  late final PendingAnswerRepository _pendingRepo;
  late final SyncService _syncService;
  late final LocalExamCacheRepository _examCache;

  List<PendingAnswerRecord> _failedAnswers = [];
  final Map<int, String> _examTitles = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _pendingRepo = context.read<PendingAnswerRepository>();
    _syncService = context.read<SyncService>();
    _examCache = LocalExamCacheRepository();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final failed = await _pendingRepo.getAllFailedAnswers();

    for (final answer in failed) {
      if (!_examTitles.containsKey(answer.sessionId)) {
        final session = await LocalDatabaseService.instance
            .getExamSessionByServerId(answer.sessionId);
        if (session != null) {
          final examId = session['exam_id'] as int;
          final exam = await _examCache.getCachedExam(examId);
          if (exam != null) {
            _examTitles[answer.sessionId] = exam.title;
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _failedAnswers = failed;
        _loading = false;
      });
    }
  }

  String _getConflictExplanation(String code) {
    return switch (code) {
      'CONFLICT_SESSION_CLOSED' =>
        'The exam session has already been submitted or has expired.',
      'SERVER_VERSION_AHEAD' =>
        'A newer version of this answer already exists on the server.',
      'VALIDATION_FAILED' =>
        'The answer was rejected by the server (e.g., invalid question ID).',
      _ => 'An unknown conflict occurred during synchronization.',
    };
  }

  Future<void> _retry(PendingAnswerRecord record) async {
    try {
      await _syncService.retryFailedSync(
        sessionId: record.sessionId,
        questionId: record.questionId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync retried successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Retry failed: $e')),
      );
    }
    _loadData();
  }

  Future<void> _discard(PendingAnswerRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Answer?'),
        content: const Text(
          'Are you sure you want to discard this answer? It will be permanently removed from the local queue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _syncService.purgeFailedAnswer(
        sessionId: record.sessionId,
        questionId: record.questionId,
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Recovery'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failedAnswers.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_done_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          const Text('All answers are synchronized.'),
          const SizedBox(height: 8),
          const Text(
            'No conflicts requiring recovery were found.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _failedAnswers.length,
      itemBuilder: (context, index) {
        final record = _failedAnswers[index];
        final examTitle = _examTitles[record.sessionId] ?? 'Unknown Exam';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            examTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Session ID: ${record.sessionId} • QID: ${record.questionId}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Chip(
                      label: Text(
                        record.conflictCode ?? 'CONFLICT',
                        style: const TextStyle(fontSize: 10),
                      ),
                      backgroundColor:
                          Theme.of(context).colorScheme.errorContainer,
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  'Conflict Detail',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  _getConflictExplanation(record.conflictCode ?? ''),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  'Selected Option:',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  record.selectedOption,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Discard'),
                      onPressed: () => _discard(record),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                      onPressed: () => _retry(record),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
