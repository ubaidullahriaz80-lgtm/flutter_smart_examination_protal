import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/exam_model.dart';
import '../../../data/models/exam_question_configuration_model.dart';
import '../../../data/models/generated_question_draft.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../../data/repositories/question_bank_repository.dart';
import '../bloc/ai_generator_bloc.dart';
import '../bloc/ai_generator_event.dart';
import '../bloc/ai_generator_state.dart';
import 'ai_question_review_view.dart';
import '../../../core/utils/responsive.dart';

const _questionTypes = ['mcq', 'true_false', 'short_answer', 'essay'];
const _difficulties = ['easy', 'medium', 'hard'];
const _bloomLevels = [
  'remember',
  'understand',
  'apply',
  'analyze',
  'evaluate',
  'create',
];

String _titleCase(String value) => value
    .split('_')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

enum GenerationSource { topic, documents }

/// AI Question Generator (FSEP novelty feature).
class AiQuestionGeneratorView extends StatefulWidget {
  const AiQuestionGeneratorView({super.key});

  @override
  State<AiQuestionGeneratorView> createState() =>
      _AiQuestionGeneratorViewState();
}

class _AiQuestionGeneratorViewState extends State<AiQuestionGeneratorView> {
  final _formKey = GlobalKey<FormState>();
  final ExamRepository _examRepository = ExamRepository();
  final ScrollController _scrollController = ScrollController();

  late Future<List<ExamModel>> _examsFuture;

  final _topicController = TextEditingController();
  final _countController = TextEditingController(text: '3');
  final _marksController = TextEditingController(text: '5');

  GenerationSource _source = GenerationSource.topic;
  final List<PlatformFile> _selectedFiles = [];

  final List<ExamModel> _selectedExams = [];
  final Set<String> _selectedQuestionTypes = {_questionTypes.first};
  String _difficulty = _difficulties[1]; // medium
  String _bloomLevel = _bloomLevels[1]; // understand

  late final AiGeneratorBloc _bloc;

  void _applyConfiguration(ExamQuestionConfigurationModel config) {
    setState(() {
      _selectedQuestionTypes.clear();
      _selectedQuestionTypes.add(config.questionType);
      _bloomLevel = config.bloomTaxonomy;
      _marksController.text = config.marks.round().toString();
      _countController.text = config.questionCount.toString();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied configuration: ${_titleCase(config.questionType)} (${config.questionCount} items)')),
    );
  }

  @override
  void initState() {
    super.initState();
    _bloc = AiGeneratorBloc(repository: QuestionBankRepository());
    _examsFuture = _examRepository.getExams();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _bloc.close();
    _topicController.dispose();
    _countController.dispose();
    _marksController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt'],
      allowMultiple: true,
    );

    if (picked.isEmpty) return;

    setState(() {
      _selectedFiles.addAll(picked);
      if (_selectedFiles.length > 10) {
        _selectedFiles.removeRange(10, _selectedFiles.length);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 10 documents allowed.')),
        );
      }
    });
  }

  void _removeFile(int index) {
    setState(() => _selectedFiles.removeAt(index));
  }

  void _generate(BuildContext context) {
    FocusScope.of(context).unfocus();

    if (_source == GenerationSource.topic) {
      if (!_formKey.currentState!.validate()) return;
    } else {
      if (_selectedFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one document.')),
        );
        return;
      }
    }

    if (_selectedExams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one exam/course.')),
      );
      return;
    }
    if (_selectedQuestionTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one question type.')),
      );
      return;
    }

    if (_source == GenerationSource.topic) {
      _bloc.add(AiGeneratorGenerateFromTopic(
        examIds: [for (final exam in _selectedExams) exam.id],
        topic: _topicController.text.trim(),
        questionTypes: _selectedQuestionTypes.toList(),
        difficulty: _difficulty,
        bloomTaxonomy: _bloomLevel,
        count: int.tryParse(_countController.text) ?? 3,
        marks: int.tryParse(_marksController.text) ?? 5,
      ));
    } else {
      final paths = _selectedFiles.map((f) => f.path).whereType<String>().toList();
      _bloc.add(AiGeneratorUploadDocuments(
        filePaths: paths,
        examIds: [for (final exam in _selectedExams) exam.id],
        questionTypes: _selectedQuestionTypes.toList(),
        difficulty: _difficulty,
        bloomTaxonomy: _bloomLevel,
        count: int.tryParse(_countController.text) ?? 3,
        marks: int.tryParse(_marksController.text) ?? 5,
      ));
    }
  }

  void _removeExam(ExamModel exam) {
    setState(() => _selectedExams.removeWhere((e) => e.id == exam.id));
  }

  Future<void> _addExam(List<ExamModel> allExams) async {
    final available = allExams
        .where((exam) => !_selectedExams.any((e) => e.id == exam.id))
        .toList();

    final chosen = await showDialog<ExamModel>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Add Exam / Course'),
        children: [
          if (available.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text('All exams/courses are already selected.'),
            ),
          for (final exam in available)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(exam),
              child: Text(
                exam.courseCode != null
                    ? '${exam.title} (${exam.courseCode})'
                    : exam.title,
              ),
            ),
        ],
      ),
    );

    if (chosen != null) {
      setState(() => _selectedExams.add(chosen));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI Question Generator'),
        ),
        body: BlocListener<AiGeneratorBloc, AiGeneratorState>(
          listener: (context, state) {
            if (state is AiGeneratorResultReady) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      'Generated ${state.drafts.length} question(s) successfully!',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(
                    _scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                  );
                }
              });
            } else if (state is AiGeneratorJobStarted) {
              _selectedFiles.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Documents uploaded. Questions are being generated...'),
                ),
              );
            } else if (state is AiGeneratorError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
          },
          child: BlocBuilder<AiGeneratorBloc, AiGeneratorState>(
            builder: (context, state) {
              return Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: context.isMobile ? double.infinity : context.screenWidth * 0.6,
                      minWidth: context.isMobile ? double.infinity : 600,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Generate exam questions with AI',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 16),
                                  SegmentedButton<GenerationSource>(
                                    segments: const [
                                      ButtonSegment(
                                        value: GenerationSource.topic,
                                        label: Text('Topic'),
                                        icon: Icon(Icons.topic_outlined),
                                      ),
                                      ButtonSegment(
                                        value: GenerationSource.documents,
                                        label: Text('Syllabus Documents'),
                                        icon: Icon(Icons.description_outlined),
                                      ),
                                    ],
                                    selected: {_source},
                                    onSelectionChanged: (set) =>
                                        setState(() => _source = set.first),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Exams / Courses',
                                    style: Theme.of(context).textTheme.labelLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  if (_selectedExams.isEmpty)
                                    Text(
                                      'No exams/courses selected',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.outline,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final exam in _selectedExams)
                                          Chip(
                                            label: Text(
                                              exam.courseCode != null
                                                  ? '${exam.title} (${exam.courseCode})'
                                                  : exam.title,
                                            ),
                                            onDeleted: () => _removeExam(exam),
                                          ),
                                      ],
                                    ),
                                  const SizedBox(height: 8),
                                  FutureBuilder<List<ExamModel>>(
                                    future: _examsFuture,
                                    builder: (context, snapshot) {
                                      final exams = snapshot.data ?? [];
                                      return OutlinedButton.icon(
                                        onPressed: exams.isEmpty
                                            ? null
                                            : () => _addExam(exams),
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add Exam/Course'),
                                      );
                                    },
                                  ),
                                  if (_selectedExams.any((e) => e.questionConfigurations.isNotEmpty)) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      'Configurations from Selected Exams',
                                      style: Theme.of(context).textTheme.labelLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final exam in _selectedExams)
                                          for (final config in exam.questionConfigurations)
                                            ActionChip(
                                              avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
                                              label: Text('${_titleCase(config.questionType)} x${config.questionCount}'),
                                              onPressed: () => _applyConfiguration(config),
                                            ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  if (_source == GenerationSource.topic)
                                    TextFormField(
                                      controller: _topicController,
                                      decoration: const InputDecoration(
                                        labelText: 'Topic',
                                        hintText: 'e.g. Computer Networks',
                                      ),
                                      validator: (value) =>
                                          (value == null || value.trim().isEmpty)
                                              ? 'Topic is required'
                                              : null,
                                    )
                                  else ...[
                                    Text(
                                      'Syllabus / Lecture Notes (PDF/TXT)',
                                      style: Theme.of(context).textTheme.labelLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    if (_selectedFiles.isEmpty)
                                      Text(
                                        'No documents selected (Max 10, 20MB each)',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.outline,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      )
                                    else
                                      Column(
                                        children: [
                                          for (var i = 0; i < _selectedFiles.length; i++)
                                            ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              leading: const Icon(Icons.file_present),
                                              title: Text(_selectedFiles[i].name),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.close),
                                                onPressed: () => _removeFile(i),
                                              ),
                                            ),
                                        ],
                                      ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: _selectedFiles.length >= 10 ? null : _pickFiles,
                                      icon: const Icon(Icons.upload_file),
                                      label: const Text('Add Document'),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Text(
                                    'Question Types',
                                    style: Theme.of(context).textTheme.labelLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final type in _questionTypes)
                                        FilterChip(
                                          label: Text(_titleCase(type)),
                                          selected: _selectedQuestionTypes.contains(type),
                                          onSelected: (selected) => setState(() {
                                            if (selected) {
                                              _selectedQuestionTypes.add(type);
                                            } else {
                                              _selectedQuestionTypes.remove(type);
                                            }
                                          }),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                    initialValue: _difficulty,
                                    isExpanded: true,
                                    decoration:
                                        const InputDecoration(labelText: 'Difficulty'),
                                    items: [
                                      for (final level in _difficulties)
                                        DropdownMenuItem(
                                          value: level,
                                          child: Text(
                                            _titleCase(level),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => _difficulty = value!),
                                  ),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                    initialValue: _bloomLevel,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: "Bloom's Taxonomy",
                                    ),
                                    items: [
                                      for (final level in _bloomLevels)
                                        DropdownMenuItem(
                                          value: level,
                                          child: Text(
                                            _titleCase(level),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => _bloomLevel = value!),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _countController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Number of Questions',
                                          ),
                                          validator: (value) {
                                            final n = int.tryParse(value ?? '');
                                            if (n == null || n < 1 || n > 10) {
                                              return '1-10';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: DropdownButtonFormField<int>(
                                          initialValue: int.tryParse(_marksController.text) ?? 1,
                                          decoration: const InputDecoration(
                                            labelText: 'Marks per Question',
                                          ),
                                          items: [
                                            for (final val in [1, 2, 3, 4, 5, 10])
                                              DropdownMenuItem(value: val, child: Text('$val')),
                                          ],
                                          onChanged: (val) => setState(() => _marksController.text = val!.toString()),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  FilledButton.icon(
                                    onPressed: state is AiGeneratorLoading ? null : () => _generate(context),
                                    icon: state is AiGeneratorLoading
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.auto_awesome),
                                    label: Text(
                                      state is AiGeneratorLoading
                                          ? 'Generating...'
                                          : 'Generate Questions',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (state is AiGeneratorLoading) ...[
                          const SizedBox(height: 16),
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  LinearProgressIndicator(),
                                  SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.auto_awesome, color: Colors.teal),
                                      SizedBox(width: 8),
                                      Text(
                                        'Generating questions with Google Gemini AI...',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'This usually takes 5–15 seconds. Please wait.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (state is AiGeneratorResultReady) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Generated Questions (${state.drafts.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < state.drafts.length; i++) ...[
                            _GeneratedQuestionCard(
                              index: i,
                              draft: state.drafts[i],
                              saving: state.savingIndexes.contains(i),
                              saved: state.savedIndexes.contains(i),
                              onSave: () => context.read<AiGeneratorBloc>().add(AiGeneratorSaveDraft(state.drafts[i], i)),
                              onDiscard: () => context.read<AiGeneratorBloc>().add(AiGeneratorDiscardDraft(i)),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                        if (state is AiGeneratorJobStarted) ...[
                          const SizedBox(height: 24),
                          _ActiveJobCard(
                            jobId: state.jobId,
                            status: state.status,
                            onRefresh: () => context.read<AiGeneratorBloc>().add(AiGeneratorPollJobStatus(state.jobId)),
                            onViewResults: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AiQuestionReviewView(jobId: state.jobId),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  const _ActiveJobCard({
    required this.jobId,
    required this.status,
    required this.onRefresh,
    required this.onViewResults,
  });

  final int jobId;
  final String status;
  final VoidCallback onRefresh;
  final VoidCallback onViewResults;

  @override
  Widget build(BuildContext context) {
    final bool isReady = status == 'REVIEW_PENDING' || status == 'COMPLETED';
    final bool isFailed = status == 'FAILED';

    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Generation Job #$jobId',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isFailed ? Theme.of(context).colorScheme.error : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isReady && !isFailed)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh Status'),
                ),
                if (isReady) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onViewResults,
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: const Text('Review Questions'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneratedQuestionCard extends StatelessWidget {
  const _GeneratedQuestionCard({
    required this.index,
    required this.draft,
    required this.saving,
    required this.saved,
    required this.onSave,
    required this.onDiscard,
  });

  final int index;
  final GeneratedQuestionDraft draft;
  final bool saving;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    draft.questionText,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const Chip(
                  label: Text('AI Generated', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _MetaChip(_titleCase(draft.questionType)),
                _MetaChip('${draft.marks.toInt()} marks'),
                _MetaChip(_titleCase(draft.difficulty)),
                _MetaChip(_titleCase(draft.bloomTaxonomy)),
                if (draft.topicTag != null) _MetaChip(draft.topicTag!),
              ],
            ),
            if (draft.options.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final option in draft.options)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        option == draft.correctAnswer
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 18,
                        color: option == draft.correctAnswer
                            ? Colors.green
                            : Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(option.toString())),
                    ],
                  ),
                ),
            ] else if (draft.correctAnswer != null) ...[
              const SizedBox(height: 10),
              Text(
                'Correct answer: ${draft.correctAnswer}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: saved ? null : onDiscard,
                  child: const Text('Discard'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: saved ? null : (saving ? null : onSave),
                  icon: saving
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(saved ? Icons.check : Icons.save_outlined),
                  label: Text(
                    saved
                        ? 'Saved'
                        : (saving ? 'Saving...' : 'Save to Question Bank'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
    );
  }
}
