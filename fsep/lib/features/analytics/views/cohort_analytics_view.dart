import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/cohort_analytics_model.dart';
import '../../../data/models/exam_model.dart';
import '../../../data/repositories/analytics_repository.dart';
import '../../../data/repositories/exam_repository.dart';

/// Cohort/Admin Analytics — examiner/system_administrator only. A single
/// screen: exam selector, summary cards, a simple score-distribution bar
/// view (no chart package exists in this project, so plain widgets are
/// used rather than adding one), and a per-exam table. All figures come
/// straight from GET /api/analytics/cohort — nothing is computed here.
class CohortAnalyticsView extends StatefulWidget {
  const CohortAnalyticsView({super.key});

  @override
  State<CohortAnalyticsView> createState() => _CohortAnalyticsViewState();
}

class _CohortAnalyticsViewState extends State<CohortAnalyticsView> {
  final AnalyticsRepository _analyticsRepository = AnalyticsRepository();
  final ExamRepository _examRepository = ExamRepository();

  late Future<List<ExamModel>> _examsFuture;
  late Future<CohortAnalytics> _analyticsFuture;
  int? _selectedExamId;

  @override
  void initState() {
    super.initState();
    _examsFuture = _examRepository.getExams();
    _analyticsFuture = _analyticsRepository.getCohortAnalytics();
  }

  void _loadAnalytics() {
    _analyticsFuture =
        _analyticsRepository.getCohortAnalytics(examId: _selectedExamId);
  }

  Future<void> _refresh() async {
    setState(_loadAnalytics);
    await _analyticsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cohort Analytics'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FutureBuilder<List<ExamModel>>(
                  future: _examsFuture,
                  builder: (context, snapshot) {
                    final exams = snapshot.data ?? [];
                    return DropdownButtonFormField<int?>(
                      initialValue: _selectedExamId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Exam',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'All Exams (overall cohort)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        for (final exam in exams)
                          DropdownMenuItem<int?>(
                            value: exam.id,
                            child: Text(
                              exam.courseCode != null
                                  ? '${exam.title} (${exam.courseCode})'
                                  : exam.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedExamId = value;
                          _loadAnalytics();
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                FutureBuilder<CohortAnalytics>(
                  future: _analyticsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            const Text('Unable to load analytics.'),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () => setState(_loadAnalytics),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final analytics = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_selectedExamId != null) ...[
                          _CohortExportButtons(examId: _selectedExamId!),
                          const SizedBox(height: 16),
                        ],
                        _SummaryCards(summary: analytics.summary),
                        const SizedBox(height: 16),
                        _AdditionalSummaryCards(
                          summary: analytics.summary,
                          reliability: analytics.deviceReliability,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Academic Score Distribution',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _ScoreDistributionChart(
                          buckets: analytics.scoreDistribution,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Behavioral Risk Distribution',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _ScoreDistributionChart(
                          buckets: analytics.behavioralRiskDistribution,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Per-Exam Statistics',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _ExamStatisticsTable(
                          statistics: analytics.examStatistics,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CohortExportButtons extends StatefulWidget {
  const _CohortExportButtons({required this.examId});

  final int examId;

  @override
  State<_CohortExportButtons> createState() => _CohortExportButtonsState();
}

class _CohortExportButtonsState extends State<_CohortExportButtons> {
  final AnalyticsRepository _repository = AnalyticsRepository();

  bool _exportingPdf = false;
  bool _exportingExcel = false;

  Future<void> _export({required bool isPdf}) async {
    setState(() {
      if (isPdf) {
        _exportingPdf = true;
      } else {
        _exportingExcel = true;
      }
    });

    try {
      final bytes = isPdf
          ? await _repository.getCohortPdf(widget.examId)
          : await _repository.getCohortExcel(widget.examId);

      final fileName =
          'fsep-cohort-${widget.examId}.${isPdf ? 'pdf' : 'xlsx'}';

      final savedUri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: isPdf
            ? 'application/pdf'
            : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (!mounted) return;
      if (savedUri != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Saved $fileName')));
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Export failed: ${error.message}')),
        );
    } finally {
      if (mounted) {
        setState(() {
          if (isPdf) {
            _exportingPdf = false;
          } else {
            _exportingExcel = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Text(
              'Export Cohort Data:',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _exportingPdf ? null : () => _export(isPdf: true),
              icon: _exportingPdf
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('PDF'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _exportingExcel ? null : () => _export(isPdf: false),
              icon: _exportingExcel
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.grid_on_outlined, size: 18),
              label: const Text('Excel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});

  final CohortSummary summary;

  String _fmtPct(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryCard(label: 'Candidates', value: '${summary.candidateCount}'),
        _SummaryCard(label: 'Eligible Total', value: '${summary.totalEligibleCandidates}'),
        _SummaryCard(label: 'Completion %', value: _fmtPct(summary.completionRate)),
        _SummaryCard(label: 'Submissions', value: '${summary.submissionCount}'),
        _SummaryCard(
          label: 'Pending Review',
          value: '${summary.pendingManualReviewCount}',
        ),
      ],
    );
  }
}

class _AdditionalSummaryCards extends StatelessWidget {
  const _AdditionalSummaryCards({
    required this.summary,
    required this.reliability,
  });

  final CohortSummary summary;
  final DeviceReliability reliability;

  String _fmtPct(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}%';
  String _fmtNum(double? v) => v == null ? '—' : v.toStringAsFixed(2);
  String _fmtMin(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}m';

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryCard(label: 'Average %', value: _fmtPct(summary.averagePercentage)),
        _SummaryCard(label: 'Highest %', value: _fmtPct(summary.highestPercentage)),
        _SummaryCard(label: 'Lowest %', value: _fmtPct(summary.lowestPercentage)),
        _SummaryCard(label: 'Average Score', value: _fmtNum(summary.averageScore)),
        _SummaryCard(
          label: 'Median Duration',
          value: _fmtMin(summary.medianCompletionTime),
        ),
        _SummaryCard(
          label: 'Device Reliability',
          value: _fmtPct(reliability.reliabilityRate),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Deliberately plain widgets (Container heights proportional to count) —
/// no chart package exists in this project's dependencies, and adding one
/// solely for this bar view was explicitly out of scope.
class _ScoreDistributionChart extends StatelessWidget {
  const _ScoreDistributionChart({required this.buckets, this.color});

  final List<ScoreDistributionBucket> buckets;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final maxCount = buckets.fold<int>(
      0,
      (max, b) => b.count > max ? b.count : max,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final bucket in buckets)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${bucket.count}', style: const TextStyle(fontSize: 10)),
                        const SizedBox(height: 4),
                        Container(
                          height: maxCount == 0
                              ? 2
                              : 5 + (bucket.count / maxCount) * 100,
                          decoration: BoxDecoration(
                            color: color ?? Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bucket.range,
                          style: const TextStyle(fontSize: 9),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamStatisticsTable extends StatelessWidget {
  const _ExamStatisticsTable({required this.statistics});

  final List<ExamStatistic> statistics;

  String _fmtPct(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}%';
  String _fmtNum(double? v) => v == null ? '—' : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    if (statistics.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No exams found.'),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Exam')),
            DataColumn(label: Text('Course')),
            DataColumn(label: Text('Submissions')),
            DataColumn(label: Text('Avg Marks')),
            DataColumn(label: Text('Avg %')),
            DataColumn(label: Text('Highest')),
            DataColumn(label: Text('Lowest')),
          ],
          rows: [
            for (final stat in statistics)
              DataRow(cells: [
                DataCell(Text(stat.examTitle)),
                DataCell(Text(stat.courseCode ?? '—')),
                DataCell(Text('${stat.submissionCount}')),
                DataCell(Text(_fmtNum(stat.averageMarks))),
                DataCell(Text(_fmtPct(stat.averagePercentage))),
                DataCell(Text(_fmtNum(stat.highestScore))),
                DataCell(Text(_fmtNum(stat.lowestScore))),
              ]),
          ],
        ),
      ),
    );
  }
}
