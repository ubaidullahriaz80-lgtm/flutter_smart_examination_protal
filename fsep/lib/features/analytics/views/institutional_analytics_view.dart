import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../dashboard/views/dashboard_widgets.dart';

class InstitutionalAnalyticsView extends StatefulWidget {
  const InstitutionalAnalyticsView({super.key});

  @override
  State<InstitutionalAnalyticsView> createState() =>
      _InstitutionalAnalyticsViewState();
}

class _InstitutionalAnalyticsViewState extends State<InstitutionalAnalyticsView> {
  late Future<Map<String, dynamic>> _analyticsFuture;

  @override
  void initState() {
    super.initState();
    _analyticsFuture = _fetchAnalytics();
  }

  Future<Map<String, dynamic>> _fetchAnalytics() async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>('/analytics/institutional');
    return response.data ?? {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Institutional Analytics')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _analyticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final performance = (snapshot.data?['department_performance'] as List? ?? []);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Department Performance',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 300,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 100,
                      barGroups: performance.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final dept = entry.value;
                        return BarChartGroupData(
                          x: idx,
                          barRods: [
                            BarChartRodData(
                              toY: (dept['average_percentage'] as num).toDouble(),
                              color: Theme.of(context).colorScheme.primary,
                              width: 20,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= performance.length) return const SizedBox.shrink();
                              return SideTitleWidget(
                                meta: meta,
                                child: Text(performance[idx]['code'] ?? ''),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Institutional Statistics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Table(
                  border: TableBorder.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                  children: [
                    const TableRow(
                      children: [
                        _TableCell('Department', isHeader: true),
                        _TableCell('Students', isHeader: true),
                        _TableCell('Exams', isHeader: true),
                        _TableCell('Avg %', isHeader: true),
                      ],
                    ),
                    for (final dept in performance)
                      TableRow(
                        children: [
                          _TableCell(dept['name']),
                          _TableCell('${dept['student_count']}'),
                          _TableCell('${dept['exam_count']}'),
                          _TableCell('${dept['average_percentage']}%'),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool isHeader;
  const _TableCell(this.text, {this.isHeader = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isHeader ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3) : null,
      padding: const EdgeInsets.all(12),
      child: Text(
        text, 
        style: TextStyle(
          fontSize: 13,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
