import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/models/exam_question_configuration_model.dart';
import '../../bloc/exam_question_configuration_bloc.dart';
import '../../bloc/exam_question_configuration_event.dart';
import '../../bloc/exam_question_configuration_state.dart';

const _questionTypes = ['mcq', 'true_false', 'short_answer', 'essay', 'matching', 'code_snippet'];
const _bloomLevels = ['remember', 'understand', 'apply', 'analyze', 'evaluate', 'create'];
const _marksOptions = [1.0, 2.0, 3.0, 4.0, 5.0, 10.0];
const _countOptions = [1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 50];

String _titleCase(String value) => value
    .split('_')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

class QuestionConfigurationBuilder extends StatelessWidget {
  final int examId;

  const QuestionConfigurationBuilder({super.key, required this.examId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExamQuestionConfigurationBloc, ExamQuestionConfigurationState>(
      builder: (context, state) {
        final totalQuestions = state.configurations.fold<int>(0, (sum, e) => sum + e.questionCount);
        final totalMarks = state.configurations.fold<double>(0.0, (sum, e) => sum + (e.questionCount * e.marks));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question Configuration',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => context.read<ExamQuestionConfigurationBloc>().add(
                        const AddConfiguration(
                          ExamQuestionConfigurationModel(
                            questionType: 'mcq',
                            questionCount: 1,
                            bloomTaxonomy: 'remember',
                            marks: 1.0,
                          ),
                        ),
                      ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Group'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (state.configurations.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No configurations defined yet.\nAdd a group to start planning your exam.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.configurations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _ConfigurationCard(
                    index: index,
                    config: state.configurations[index],
                  );
                },
              ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryItem(label: 'Total Questions', value: '$totalQuestions'),
                  _SummaryItem(label: 'Total Marks', value: totalMarks.toStringAsFixed(0)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.icon(
                onPressed: state is ExamQuestionConfigurationLoading
                    ? null
                    : () => context.read<ExamQuestionConfigurationBloc>().add(SaveConfigurations(examId)),
                icon: state is ExamQuestionConfigurationLoading
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: const Text('Save Configuration'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConfigurationCard extends StatelessWidget {
  final int index;
  final ExamQuestionConfigurationModel config;

  const _ConfigurationCard({required this.index, required this.config});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: config.questionType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [
                      for (final type in _questionTypes)
                        DropdownMenuItem(value: type, child: Text(_titleCase(type))),
                    ],
                    onChanged: (val) => context.read<ExamQuestionConfigurationBloc>().add(
                          UpdateConfiguration(index, config.copyWith(questionType: val)),
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: config.questionCount,
                    decoration: const InputDecoration(labelText: 'Count'),
                    items: [
                      for (final val in _countOptions) DropdownMenuItem(value: val, child: Text('$val')),
                    ],
                    onChanged: (val) => context.read<ExamQuestionConfigurationBloc>().add(
                          UpdateConfiguration(index, config.copyWith(questionCount: val)),
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: config.bloomTaxonomy,
                    decoration: const InputDecoration(labelText: 'Bloom'),
                    items: [
                      for (final level in _bloomLevels)
                        DropdownMenuItem(value: level, child: Text(_titleCase(level))),
                    ],
                    onChanged: (val) => context.read<ExamQuestionConfigurationBloc>().add(
                          UpdateConfiguration(index, config.copyWith(bloomTaxonomy: val)),
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<double>(
                    value: config.marks,
                    decoration: const InputDecoration(labelText: 'Marks Each'),
                    items: [
                      for (final val in _marksOptions)
                        DropdownMenuItem(value: val, child: Text(val.toStringAsFixed(0))),
                    ],
                    onChanged: (val) => context.read<ExamQuestionConfigurationBloc>().add(
                          UpdateConfiguration(index, config.copyWith(marks: val)),
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => context.read<ExamQuestionConfigurationBloc>().add(RemoveConfiguration(index)),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
