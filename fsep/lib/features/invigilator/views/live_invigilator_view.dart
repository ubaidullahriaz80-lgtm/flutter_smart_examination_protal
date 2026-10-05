import 'package:flutter/material.dart';

import '../../../data/repositories/exam_session_repository.dart';
import 'bcd_dashboard_view.dart';

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

/// Live Invigilator monitoring overview (List 1 Item — Live Invigilator).
/// Reuses the existing Behavioral Cheating Detection data end-to-end —
/// GET /exam-sessions for the list, GET /exam-sessions/{id}/behavior-events
/// for the drill-down — nothing here computes or invents suspicion data.
class LiveInvigilatorView extends StatefulWidget {
  const LiveInvigilatorView({super.key});

  @override
  State<LiveInvigilatorView> createState() => _LiveInvigilatorViewState();
}

class _LiveInvigilatorViewState extends State<LiveInvigilatorView> {
  final ExamSessionRepository _repository = ExamSessionRepository();

  late Future<List<InvigilatorSessionModel>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    _sessionsFuture = _repository.getActiveSessions();
  }

  Future<void> _refresh() async {
    setState(_loadSessions);
    await _sessionsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Invigilator'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_loadSessions),
          ),
        ],
      ),
      body: FutureBuilder<List<InvigilatorSessionModel>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    const Text('Unable to load exam sessions.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(_loadSessions),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final sessions = snapshot.data ?? [];

          if (sessions.isEmpty) {
            return const Center(
              child: Text(
                'No active exam sessions found.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _SessionCard(
                  session: session,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            _SessionDetailView(session: session),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onTap});

  final InvigilatorSessionModel session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.candidateName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Chip(
                    avatar: Icon(
                      Icons.visibility_outlined,
                      size: 16,
                      color: _statusColor(context, session.suspicion.status),
                    ),
                    label: Text(_statusLabel(session.suspicion.status)),
                    labelStyle: const TextStyle(fontSize: 11),
                    visualDensity: VisualDensity.compact,
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _InfoItem(
                    icon: Icons.quiz_outlined,
                    label: session.examTitle,
                  ),
                  _InfoItem(
                    icon: Icons.confirmation_number_outlined,
                    label: 'Session #${session.sessionId}',
                  ),
                  _InfoItem(
                    icon: Icons.flag_outlined,
                    label: session.status,
                  ),
                  _InfoItem(
                    icon: Icons.warning_amber_outlined,
                    label: 'Score: ${session.suspicion.score}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.stream, size: 18),
                  label: const Text('Live Monitor'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BcdDashboardView(
                          examId: session.examId,
                          examTitle: session.examTitle,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionDetailView extends StatefulWidget {
  const _SessionDetailView({required this.session});

  final InvigilatorSessionModel session;

  @override
  State<_SessionDetailView> createState() => _SessionDetailViewState();
}

class _SessionDetailViewState extends State<_SessionDetailView> {
  final ExamSessionRepository _repository = ExamSessionRepository();

  late Future<BehaviorEventLog> _logFuture;

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  void _loadLog() {
    _logFuture = _repository.getBehaviorEvents(widget.session.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_loadLog),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Candidate',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(session.candidateName),
                    Text(
                      session.candidateEmail,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Exam',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(session.examTitle),
                    Text(
                      'Session #${session.sessionId} — ${session.status}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<BehaviorEventLog>(
              future: _logFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        const Text('Unable to load behavioral events.'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => setState(_loadLog),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final log = snapshot.data!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              color: _statusColor(
                                context,
                                log.suspicion.status,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _statusLabel(log.suspicion.status),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: _statusColor(
                                            context,
                                            log.suspicion.status,
                                          ),
                                        ),
                                  ),
                                  Text('Suspicion score: ${log.suspicion.score}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Behavioral Events (${log.events.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (log.events.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No behavioral events recorded.'),
                      )
                    else
                      for (final event in log.events)
                        _EventTile(event: event),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final BehaviorEventEntry event;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          event.suspicionPoints > 0
              ? Icons.warning_amber_outlined
              : Icons.info_outline,
          color: event.suspicionPoints > 0 ? Colors.orange : null,
        ),
        title: Text(event.eventType.replaceAll('_', ' ')),
        subtitle: Text(event.occurredAt.toString()),
        trailing: Text('+${event.suspicionPoints} pts'),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 5),
        Text(label),
      ],
    );
  }
}
