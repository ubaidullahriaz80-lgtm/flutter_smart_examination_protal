import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/exam_model.dart';
import '../../../data/models/exam_question_configuration_model.dart';
import '../../../data/models/generated_question_draft.dart';
import '../../../data/models/question_model.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../../data/repositories/question_bank_repository.dart';
import '../bloc/question_bloc.dart';
import '../bloc/question_event.dart';
import '../bloc/question_state.dart';
import '../../../core/utils/responsive.dart';

const _questionTypes = ['mcq', 'true_false', 'short_answer', 'essay', 'matching', 'code_snippet'];
const _difficulties = ['easy', 'medium', 'hard'];
const _bloomLevels = [
  'remember',
  'understand',
  'apply',
  'analyze',
  'evaluate',
  'create',
];

const _marksOptions = [1, 2, 3, 4, 5, 10];

String _titleCase(String value) => switch (value) {
      'short_answer' => 'Short Question',
      'essay' => 'Long Question',
      _ => value.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
    };

/// Manual create/edit form for Question Bank entries.
class QuestionFormView extends StatefulWidget {
  const QuestionFormView({super.key, this.existingQuestion});

  final QuestionModel? existingQuestion;

  @override
  State<QuestionFormView> createState() => _QuestionFormViewState();
}

class _QuestionFormViewState extends State<QuestionFormView> {
  final _formKey = GlobalKey<FormState>();
  final ExamRepository _examRepository = ExamRepository();

  late final TextEditingController _questionTextController;
  late final TextEditingController _topicTagController;
  late final TextEditingController _correctAnswerController;
  late final TextEditingController _keywordsController;
  late final TextEditingController _regexController;

  late Future<List<ExamModel>> _examsFuture;
  List<ExamModel> _allExams = [];
  ExamModel? _selectedExam;
  int? _selectedExamId;
  String _questionType = _questionTypes.first;
  String _difficulty = _difficulties[1]; // medium
  String _bloomLevel = _bloomLevels[0]; // remember
  int _marks = 1;

  // MCQ options
  final List<TextEditingController> _optionControllers = [];

  // Matching pairs
  final List<MapEntry<TextEditingController, TextEditingController>>
      _matchingPairControllers = [];

  String? _submitError;

  @override
  void initState() {
    super.initState();
    _examsFuture = _examRepository.getExams().then((exams) {
      _allExams = exams;
      if (_selectedExamId != null) {
        _selectedExam = exams.firstWhere((e) => e.id == _selectedExamId);
      }
      return exams;
    });

    final q = widget.existingQuestion;
    _questionTextController = TextEditingController(text: q?.questionText ?? '');
    _topicTagController = TextEditingController(text: q?.topicTag ?? '');
    _correctAnswerController =
        TextEditingController(text: q?.correctAnswer ?? '');
    _keywordsController =
        TextEditingController(text: q?.keywords.join(', ') ?? '');
    _regexController =
        TextEditingController(text: q?.regexPatterns.join('\n') ?? '');

    if (q != null) {
      _selectedExamId = q.examId;
      _questionType = q.questionType;
      _difficulty = q.difficulty ?? _difficulties[1];
      _bloomLevel = q.bloomTaxonomy ?? _bloomLevels[0];
      _marks = q.marks.round();

      if (_questionType == 'mcq') {
        for (final opt in q.options) {
          _optionControllers.add(TextEditingController(text: opt));
        }
      } else if (_questionType == 'matching') {
        for (final pair in q.matchingPairs) {
          _matchingPairControllers.add(MapEntry(
            TextEditingController(text: pair.left),
            TextEditingController(text: pair.right),
          ));
        }
      }
    }

    if (_optionControllers.isEmpty && _questionType == 'mcq') {
      _addOption();
      _addOption();
    }
    if (_matchingPairControllers.isEmpty && _questionType == 'matching') {
      _addMatchingPair();
      _addMatchingPair();
    }
  }

  @override
  void dispose() {
    _questionTextController.dispose();
    _topicTagController.dispose();
    _correctAnswerController.dispose();
    _keywordsController.dispose();
    _regexController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    for (final p in _matchingPairControllers) {
      p.key.dispose();
      p.value.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    setState(() => _optionControllers.removeAt(index).dispose());
  }

  void _addMatchingPair() {
    setState(() => _matchingPairControllers.add(MapEntry(
          TextEditingController(),
          TextEditingController(),
        )));
  }

  void _removeMatchingPair(int index) {
    final pair = _matchingPairControllers.removeAt(index);
    pair.key.dispose();
    pair.value.dispose();
    setState(() {});
  }

  void _applyConfiguration(ExamQuestionConfigurationModel config) {
    setState(() {
      _questionType = config.questionType;
      _marks = config.marks.round();
      _bloomLevel = config.bloomTaxonomy;

      // Initialize controllers for new type if needed
      if (_questionType == 'mcq' && _optionControllers.isEmpty) {
        _addOption();
        _addOption();
      }
      if (_questionType == 'matching' && _matchingPairControllers.isEmpty) {
        _addMatchingPair();
        _addMatchingPair();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Applied Blueprint: ${_titleCase(config.questionType)} - '
          '${_titleCase(config.bloomTaxonomy)} (${config.marks.round()} pts)',
        ),
      ),
    );
  }

  void _submit(BuildContext context, {bool addAnother = false}) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedExamId == null) {
      setState(() => _submitError = 'Please select an exam/course.');
      return;
    }

    final options = _optionControllers.map((c) => c.text.trim()).toList();
    if (_questionType == 'mcq' && options.any((o) => o.isEmpty)) {
      setState(() => _submitError = 'All options must be filled.');
      return;
    }

    final List<Object> finalOptions = _questionType == 'mcq'
        ? List<Object>.from(options)
        : (_questionType == 'matching'
            ? _matchingPairControllers
                .map((p) => {'left': p.key.text.trim(), 'right': p.value.text.trim()})
                .toList()
            : []);

    final correctedDraft = GeneratedQuestionDraft(
      examId: _selectedExamId!,
      questionText: _questionTextController.text.trim(),
      questionType: _questionType,
      marks: _marks,
      difficulty: _difficulty,
      bloomTaxonomy: _bloomLevel,
      topicTag: _topicTagController.text.trim().isEmpty ? null : _topicTagController.text.trim(),
      options: finalOptions,
      correctAnswer: _correctAnswerController.text.trim().isEmpty ? null : _correctAnswerController.text.trim(),
      keywords: _keywordsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      regexPatterns: _regexController.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      isAiGenerated: widget.existingQuestion?.isAiGenerated ?? false,
    );

    final bloc = context.read<QuestionBloc>();

    if (widget.existingQuestion != null) {
      final updated = QuestionModel(
        id: widget.existingQuestion!.id,
        examId: correctedDraft.examId,
        questionText: correctedDraft.questionText,
        questionType: correctedDraft.questionType,
        marks: _marks.toDouble(),
        difficulty: correctedDraft.difficulty,
        bloomTaxonomy: correctedDraft.bloomTaxonomy,
        topicTag: correctedDraft.topicTag,
        options: _questionType == 'matching' ? [] : options,
        matchingPairs: _questionType == 'matching'
            ? _matchingPairControllers
                .map((p) => MatchingPair(left: p.key.text.trim(), right: p.value.text.trim()))
                .toList()
            : [],
        correctAnswer: correctedDraft.correctAnswer,
        keywords: correctedDraft.keywords,
        regexPatterns: correctedDraft.regexPatterns,
        isAiGenerated: correctedDraft.isAiGenerated,
        reviewStatus: widget.existingQuestion!.reviewStatus,
      );

      bloc.add(UpdateQuestion(updated, reviewStatus: updated.reviewStatus));
      await bloc.stream.firstWhere((s) => s is QuestionOperationSuccess || s is QuestionError);
      if (mounted && bloc.state is QuestionOperationSuccess) {
        Navigator.of(context).pop(true);
      }
    } else {
      bloc.add(CreateQuestion(correctedDraft));
      await bloc.stream.firstWhere((s) => s is QuestionOperationSuccess || s is QuestionError);
      if (mounted && bloc.state is QuestionOperationSuccess) {
        if (addAnother) {
          _questionTextController.clear();
          _correctAnswerController.clear();
          for (final c in _optionControllers) {
            c.clear();
          }
          for (final p in _matchingPairControllers) {
            p.key.clear();
            p.value.clear();
          }
          setState(() {
            _submitError = null;
          });
        } else {
          Navigator.of(context).pop(true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => QuestionBloc(repository: QuestionBankRepository()),
      child: BlocListener<QuestionBloc, QuestionState>(
        listener: (context, state) {
          if (state is QuestionOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is QuestionError) {
            setState(() => _submitError = state.message);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
                widget.existingQuestion != null ? 'Edit Question' : 'Add Question'),
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: context.isMobile ? double.infinity : context.screenWidth * 0.6,
                    minWidth: context.isMobile ? double.infinity : 400,
                  ),
                  child: BlocBuilder<QuestionBloc, QuestionState>(
                    builder: (context, state) {
                      return Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FutureBuilder<List<ExamModel>>(
                              future: _examsFuture,
                              builder: (context, snapshot) {
                                final exams = snapshot.data ?? [];
                                return DropdownButtonFormField<int>(
                                  initialValue: _selectedExamId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Exam / Course',
                                  ),
                                  items: [
                                    for (final exam in exams)
                                      DropdownMenuItem(
                                        value: exam.id,
                                        child: Text(
                                          exam.courseCode != null
                                              ? '${exam.title} (${exam.courseCode})'
                                              : exam.title,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (value) => setState(() {
                                    _selectedExamId = value;
                                    _selectedExam = _allExams.firstWhere((e) => e.id == value);
                                  }),
                                  validator: (value) =>
                                      value == null ? 'Select an exam/course' : null,
                                );
                              },
                            ),
                            if (_selectedExam != null && _selectedExam!.questionConfigurations.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Apply Exam Blueprint',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final config in _selectedExam!.questionConfigurations)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: ActionChip(
                                          avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
                                          label: Text(
                                            '${_titleCase(config.questionType)} - '
                                            '${_titleCase(config.bloomTaxonomy)} (${config.marks.round()} pts)',
                                          ),
                                          onPressed: () => _applyConfiguration(config),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _questionTextController,
                              maxLines: 3,
                              decoration:
                                  const InputDecoration(labelText: 'Question Text'),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                      ? 'Question text is required'
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _questionType,
                              isExpanded: true,
                              decoration:
                                  const InputDecoration(labelText: 'Question Type'),
                              items: [
                                for (final type in _questionTypes)
                                  DropdownMenuItem(
                                    value: type,
                                    child: Text(
                                      _titleCase(type),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _questionType = value;
                                    _submitError = null;
                                    if (_questionType == 'mcq' && _optionControllers.isEmpty) {
                                      _addOption();
                                      _addOption();
                                    }
                                    if (_questionType == 'matching' && _matchingPairControllers.isEmpty) {
                                      _addMatchingPair();
                                      _addMatchingPair();
                                    }
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              initialValue: _marks,
                              decoration: const InputDecoration(labelText: 'Marks'),
                              items: [
                                for (final val in _marksOptions)
                                  DropdownMenuItem(value: val, child: Text('$val')),
                              ],
                              onChanged: (val) => setState(() => _marks = val!),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _topicTagController,
                              decoration: const InputDecoration(labelText: 'Topic Tag'),
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
                            if (_questionType == 'mcq') ...[
                              Text('Options',
                                  style: Theme.of(context).textTheme.labelLarge),
                              for (var i = 0; i < _optionControllers.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _optionControllers[i],
                                          decoration: InputDecoration(
                                              labelText: 'Option ${i + 1}'),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: _optionControllers.length > 2
                                            ? () => _removeOption(i)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              TextButton.icon(
                                onPressed: _addOption,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Option'),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _correctAnswerController,
                                decoration: const InputDecoration(
                                  labelText: 'Correct Answer (match an option)',
                                ),
                              ),
                            ] else if (_questionType == 'matching') ...[
                              Text('Matching Pairs',
                                  style: Theme.of(context).textTheme.labelLarge),
                              for (var i = 0; i < _matchingPairControllers.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _matchingPairControllers[i].key,
                                          decoration:
                                              const InputDecoration(labelText: 'Left'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _matchingPairControllers[i].value,
                                          decoration:
                                              const InputDecoration(labelText: 'Right'),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline),
                                        onPressed: _matchingPairControllers.length > 2
                                            ? () => _removeMatchingPair(i)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              TextButton.icon(
                                onPressed: _addMatchingPair,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Pair'),
                              ),
                            ] else if (_questionType == 'short_answer') ...[
                              TextFormField(
                                controller: _correctAnswerController,
                                decoration: const InputDecoration(
                                  labelText: 'Canonical Correct Answer',
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _keywordsController,
                                decoration: const InputDecoration(
                                  labelText: 'Keywords (comma-separated)',
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _regexController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Regex Patterns (one per line)',
                                ),
                              ),
                            ] else if (_questionType == 'true_false') ...[
                              DropdownButtonFormField<String>(
                                initialValue: _correctAnswerController.text.isEmpty
                                    ? 'True'
                                    : _correctAnswerController.text,
                                decoration:
                                    const InputDecoration(labelText: 'Correct Answer'),
                                items: ['True', 'False']
                                    .map((v) =>
                                        DropdownMenuItem(value: v, child: Text(v)))
                                    .toList(),
                                onChanged: (v) => _correctAnswerController.text = v!,
                              ),
                            ],
                            if (_submitError != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _submitError!,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: state is QuestionLoading ? null : () => _submit(context, addAnother: true),
                                    child: state is QuestionLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('Save & Add Next'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: state is QuestionLoading ? null : () => _submit(context),
                                    child: state is QuestionLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('Save & Exit'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
