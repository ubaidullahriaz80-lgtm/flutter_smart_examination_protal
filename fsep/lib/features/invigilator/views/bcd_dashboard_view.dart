import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/models/bcd_update_model.dart';
import '../../../data/repositories/exam_session_repository.dart';

class BcdDashboardView extends StatefulWidget {
  const BcdDashboardView({super.key, required this.examId, required this.examTitle});

  final int examId;
  final String examTitle;

  @override
  State<BcdDashboardView> createState() => _BcdDashboardViewState();
}

class _BcdDashboardViewState extends State<BcdDashboardView> {
  final ExamSessionRepository _repository = ExamSessionRepository();
  final Map<int, BcdUpdateModel> _sessionUpdates = {};
  StreamSubscription? _subscription;
  bool _connecting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      _subscription = _repository.getBehavioralStream(widget.examId).listen(
        (update) {
          setState(() {
            _sessionUpdates[update.sessionId] = update;
            _connecting = false;
          });
        },
        onError: (e) {
          setState(() {
            _error = 'Connection lost. Retrying...';
            _connecting = false;
          });
          // Simple reconnect logic
          Future.delayed(const Duration(seconds: 5), _startListening);
        },
        cancelOnError: true,
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to connect: $e';
        _connecting = false;
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String _statusLabel(String status) => switch (status) {
        'highly_suspicious' || 'critical' => 'Critical',
        'suspicious' || 'high' => 'High Risk',
        'medium' => 'Medium Risk',
        'low' => 'Low Risk',
        _ => 'Normal',
      };

  Color? _statusColor(BuildContext context, String status) => switch (status) {
        'highly_suspicious' || 'critical' => Theme.of(context).colorScheme.error,
        'suspicious' || 'high' => Colors.orange,
        'medium' => Colors.amber,
        'low' => Colors.green,
        _ => Colors.blueGrey,
      };

  @override
  Widget build(BuildContext context) {
    final updates = _sessionUpdates.values.toList()
      ..sort((a, b) => b.riskScore.compareTo(a.riskScore));

    return Scaffold(
      appBar: AppBar(
        title: Text('Live: ${widget.examTitle}'),
        actions: [
          if (_connecting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startListening,
            tooltip: 'Reconnect',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          Expanded(
            child: updates.isEmpty && !_connecting
                ? const Center(child: Text('Waiting for behavioral data...'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: updates.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final update = updates[index];
                      return _CandidateRiskTile(
                        update: update,
                        isNewAlert: update.isAlert,
                        label: _statusLabel(update.riskBand),
                        color: _statusColor(context, update.riskBand),
                        onReview: (eventId, action, note) async {
                          await _repository.reviewBehavioralEvent(
                            eventId: eventId,
                            action: action,
                            note: note,
                          );
                          // No manual refresh needed, next SSE update will have the status.
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CandidateRiskTile extends StatelessWidget {
  const _CandidateRiskTile({
    required this.update,
    required this.label,
    required this.color,
    this.isNewAlert = false,
    required this.onReview,
  });

  final BcdUpdateModel update;
  final String label;
  final Color? color;
  final bool isNewAlert;
  final Future<void> Function(int eventId, String action, String? note) onReview;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: isNewAlert
          ? RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).colorScheme.error, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: ExpansionTile(
        title: Text(
          update.candidateName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Current Risk Score: ${update.riskScore}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color?.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color ?? Colors.grey),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (update.eventBreakdown != null) ...[
                  const Text('Point Contribution:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final entry in update.eventBreakdown!.entries)
                        Chip(
                          label: Text('${entry.key}: ${entry.value['contribution']}'),
                          labelStyle: const TextStyle(fontSize: 10),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const Divider(),
                ],
                const Text('Latest Events:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (update.latestEvents.isEmpty)
                  const Text('No events recorded yet.')
                else
                  for (final event in update.latestEvents)
                    _EventRow(
                      event: event,
                      onReview: (action, note) => onReview(event['id'] as int, action, note),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.onReview});

  final Map<String, dynamic> event;
  final Function(String action, String? note) onReview;

  @override
  Widget build(BuildContext context) {
    final status = event['review_action'] as String?;
    final color = switch (status) {
      'Reviewed' => Colors.blue,
      'Escalated' => Colors.red,
      'Dismissed' => Colors.grey,
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event['type'].toString().replaceAll('_', ' ')),
                Text(
                  event['ts'].toString().split(' ').last.split('.').first,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                label: Text(status, style: const TextStyle(fontSize: 10)),
                backgroundColor: color?.withValues(alpha: 0.1),
                labelStyle: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                visualDensity: VisualDensity.compact,
                side: BorderSide(color: color ?? Colors.transparent),
              ),
            ),
          IconButton(
            icon: Icon(Icons.rate_review_outlined, size: 20, color: color),
            onPressed: () => _showReviewDialog(context),
            tooltip: 'Review Event',
          ),
        ],
      ),
    );
  }

  void _showReviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ReviewEventDialog(onReview: onReview),
    );
  }
}

class _ReviewEventDialog extends StatefulWidget {
  const _ReviewEventDialog({required this.onReview});

  final Function(String action, String? note) onReview;

  @override
  State<_ReviewEventDialog> createState() => _ReviewEventDialogState();
}

class _ReviewEventDialogState extends State<_ReviewEventDialog> {
  String _action = 'Reviewed';
  final _noteController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Review Behavioral Event'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _action,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Action'),
            items: ['Reviewed', 'Escalated', 'Dismissed']
                .map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(
                        a,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _action = v!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (Optional)',
              hintText: 'Enter reason or observation...',
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onReview(_action, _noteController.text.trim());
            Navigator.pop(context);
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
