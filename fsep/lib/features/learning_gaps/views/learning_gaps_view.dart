import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/learning_gap_model.dart';
import '../../../data/repositories/learning_gap_repository.dart';
import '../bloc/learning_gap_bloc.dart';
import '../bloc/learning_gap_event.dart';
import '../bloc/learning_gap_state.dart';
import '../../../core/utils/responsive.dart';

/// Learning Gap Detection (FSEP novelty feature) — candidate-facing.
/// Shows the authenticated candidate's own weak topics, computed
/// server-side from their real answers.
class LearningGapsView extends StatelessWidget {
  const LearningGapsView({super.key, this.sessionId});

  final int? sessionId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LearningGapBloc(
        repository: LearningGapRepository(),
      )..add(LoadLearningGap(sessionId: sessionId)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Learning Gaps'),
        ),
        body: BlocBuilder<LearningGapBloc, LearningGapState>(
          builder: (context, state) {
            if (state is LearningGapLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (state is LearningGapError) {
              return _ErrorView(
                onRetry: () {
                  context.read<LearningGapBloc>().add(LoadLearningGap(sessionId: sessionId));
                },
              );
            }

            if (state is LearningGapLoaded) {
              final report = state.report;

              if (report.gaps.isEmpty) {
                return _NoGapsView(
                  topicsAnalyzed: report.topicsAnalyzed,
                  questionsAttempted: report.questionsAttempted,
                );
              }

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: RefreshIndicator(
                    onRefresh: () async {
                      final bloc = context.read<LearningGapBloc>();
                      bloc.add(RefreshLearningGap(sessionId: sessionId));
                      await bloc.stream.firstWhere((s) => s is! LearningGapLoading);
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Overall Learning Summary',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _LearningSummaryHeader(report: report),
                        const SizedBox(height: 24),
                        if (context.isMobile) ...[
                          Text(
                            'Topic Mastery',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _TopicMasteryChart(allTopics: report.allTopics),
                          const SizedBox(height: 24),
                          Text(
                            'Cognitive Performance (Bloom\'s Taxonomy)',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          _BloomRadarChart(profile: report.bloomProfile),
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Topic Mastery',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 12),
                                    _TopicMasteryChart(allTopics: report.allTopics),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cognitive Performance',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 12),
                                    _BloomRadarChart(profile: report.bloomProfile),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),
                        Text(
                          'Difficulty Analysis',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _ProfileCard(profile: report.difficultyProfile),
                        const SizedBox(height: 24),
                        Text(
                          'Improvement Roadmap (Top 5)',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        for (final step in report.improvementRoadmap) ...[
                          _RoadmapCard(step: step),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          'All Topic Gaps',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        for (final gap in report.gaps) ...[
                          _LearningGapCard(gap: gap),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _LearningSummaryHeader extends StatelessWidget {
  const _LearningSummaryHeader({required this.report});

  final LearningGapReport report;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Based on ${report.questionsAttempted} attempted question'
      '${report.questionsAttempted == 1 ? '' : 's'} across '
      '${report.topicsAnalyzed} topic'
      '${report.topicsAnalyzed == 1 ? '' : 's'}, '
      '${report.gaps.length} weak topic'
      '${report.gaps.length == 1 ? '' : 's'} were detected.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _TopicMasteryChart extends StatelessWidget {
  const _TopicMasteryChart({required this.allTopics});

  final List<LearningGapModel> allTopics;

  @override
  Widget build(BuildContext context) {
    if (allTopics.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    // Sort alphabetically for stable display, or by percentage.
    final data = List<LearningGapModel>.from(allTopics)
      ..sort((a, b) => a.topic.compareTo(b.topic));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
      ),
      child: SizedBox(
        height: 240,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 100,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (group) => theme.colorScheme.surfaceContainerHigh,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${data[group.x.toInt()].topic}\n',
                    const TextStyle(fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(
                        text: '${rod.toY.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    if (value.toInt() >= data.length) return const SizedBox.shrink();
                    final topic = data[value.toInt()].topic;
                    return SideTitleWidget(
                      meta: meta,
                      space: 8,
                      child: Transform.rotate(
                        angle: -0.5,
                        child: Text(
                          topic,
                          style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600),
                          softWrap: false,
                        ),
                      ),
                    );
                  },
                  reservedSize: 80,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    return Text('${value.toInt()}%', style: const TextStyle(fontSize: 10, color: Colors.grey));
                  },
                  reservedSize: 35,
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true, 
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: theme.dividerColor.withValues(alpha: 0.05),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: [
              for (int i = 0; i < data.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: data[i].percentage,
                      gradient: LinearGradient(
                        colors: [
                          _getColor(data[i].percentage).withValues(alpha: 0.8),
                          _getColor(data[i].percentage),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: 14,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColor(double pct) {
    if (pct < 50) return Colors.redAccent;
    if (pct < 70) return Colors.orangeAccent;
    return const Color(0xFF10B981);
  }
}

class _BloomRadarChart extends StatelessWidget {
  const _BloomRadarChart({required this.profile});

  final Map<String, double?> profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<String> labels = ['Remember', 'Understand', 'Apply', 'Analyze', 'Evaluate', 'Create'];
    
    final List<RadarEntry> entries = labels.map((l) {
      return RadarEntry(value: profile[l] ?? 0);
    }).toList();

    final hasMissing = profile.values.any((v) => v == null);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 240,
            child: RadarChart(
              RadarChartData(
                dataSets: [
                  RadarDataSet(
                    fillColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderColor: theme.colorScheme.primary,
                    entryRadius: 4,
                    borderWidth: 2,
                    dataEntries: entries,
                  ),
                ],
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(color: Colors.transparent),
                titlePositionPercentageOffset: 0.2,
                titleTextStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                getTitle: (index, angle) {
                  final label = labels[index % labels.length];
                  final isNa = profile[label] == null;
                  return RadarChartTitle(
                    text: isNa ? '$label (N/A)' : label,
                    angle: 0,
                  );
                },
                tickCount: 5,
                ticksTextStyle: const TextStyle(fontSize: 8, color: Colors.grey),
                gridBorderData: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1), width: 1),
              ),
            ),
          ),
          if (hasMissing) ...[
            const SizedBox(height: 12),
            Text(
              '* N/A indicates no questions were attempted at this level.',
              style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({required this.step});

  final RoadmapStep step;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  child: Text('${step.rank}', style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step.topic,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${step.mastery.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: step.severity == 'high' ? Colors.red : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              step.suggestion,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final Map<String, double?> profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (final entry in profile.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(entry.key)),
                    Expanded(
                      flex: 5,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (entry.value ?? 0) / 100,
                          minHeight: 8,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 35,
                      child: Text(
                        entry.value != null ? '${entry.value!.toStringAsFixed(0)}%' : 'N/A',
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LearningGapCard extends StatelessWidget {
  const _LearningGapCard({required this.gap});

  final LearningGapModel gap;

  Color _severityColor(BuildContext context) => switch (gap.severity) {
        'high' => Colors.redAccent,
        'moderate' => Colors.orangeAccent,
        _ => const Color(0xFF10B981),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _severityColor(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gap.topic,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (gap.courseCode != null)
                      Text(
                        gap.courseCode!,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${gap.percentage.toStringAsFixed(0)}%',
                    style: theme.textTheme.headlineSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    'MASTERY',
                    style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: gap.percentage / 100,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.1),
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.check_circle_outline, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                '${gap.correctAnswers} / ${gap.questionsAttempted} correct',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                '${gap.obtainedMarks} / ${gap.totalMarks} marks',
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoGapsView extends StatelessWidget {
  const _NoGapsView({
    required this.topicsAnalyzed,
    required this.questionsAttempted,
  });

  final int topicsAnalyzed;
  final int questionsAttempted;

  @override
  Widget build(BuildContext context) {
    final hasAttempts = questionsAttempted > 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasAttempts ? Icons.check_circle_outline : Icons.info_outline,
              size: 56,
              color: hasAttempts ? Colors.green : null,
            ),
            const SizedBox(height: 16),
            Text(
              hasAttempts
                  ? 'No significant learning gaps detected.'
                  : 'No completed exam attempts yet.',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasAttempts
                  ? 'Your performance across $topicsAnalyzed topic'
                      '${topicsAnalyzed == 1 ? '' : 's'} is at or above the '
                      'recommended threshold.'
                  : 'Complete and submit an exam to see your learning gap analysis.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load your learning gaps.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
