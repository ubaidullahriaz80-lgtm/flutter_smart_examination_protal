import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../data/models/exam_model.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../../core/network/api_client.dart'; // Direct fetch for departments if no repo yet
import '../bloc/exam_bloc.dart';
import '../bloc/exam_event.dart';
import '../bloc/exam_state.dart';
import '../bloc/exam_question_configuration_bloc.dart';
import '../bloc/exam_question_configuration_event.dart';
import '../bloc/exam_question_configuration_state.dart';
import 'widgets/question_configuration_builder.dart';
import '../../../core/utils/responsive.dart';

const _statuses = ['draft', 'published', 'closed'];

const _platforms = [
  'android',
  'ios',
  'windows',
  'macos',
  'linux',
  'web',
];

const _negativeMarkingOptions = [0.0, 0.25, 0.50, 1.0];

String _titleCase(String value) => switch (value) {
      'ios' => 'iOS',
      'macos' => 'macOS',
      _ => value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}',
    };

/// Create/edit form for Exam Administration (examiner-only).
class ExamFormView extends StatefulWidget {
  const ExamFormView({super.key, this.existingExam});

  final ExamModel? existingExam;

  bool get isEditing => existingExam != null;

  @override
  State<ExamFormView> createState() => _ExamFormViewState();
}

class _ExamFormViewState extends State<ExamFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _courseCodeController;
  late final TextEditingController _durationController;
  late final TextEditingController _totalMarksController;
  late final TextEditingController _passPercentageController;

  late String _status;
  final Set<String> _allowedPlatforms = {};
  late bool _bcdEnabled;
  late bool _randomizeQuestions;
  late bool _shuffleChoices;
  late bool _isOfflineReady;
  DateTime? _startsAt;
  int? _selectedDepartmentId;
  int? _selectedSemester;
  late double _negativeMarkingWeight;

  late Future<List<Map<String, dynamic>>> _departmentsFuture;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingExam;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _courseCodeController =
        TextEditingController(text: existing?.courseCode ?? '');
    _durationController = TextEditingController(
      text: existing != null ? existing.durationMinutes.toString() : '',
    );
    _totalMarksController = TextEditingController(
      text: existing != null ? existing.totalMarks.toString() : '',
    );
    _passPercentageController = TextEditingController(
      text: existing != null
          ? existing.passPercentage.toString()
          : '50',
    );
    _status = existing?.status ?? _statuses.first;
    if (existing?.allowedPlatforms != null) {
      _allowedPlatforms.addAll(existing!.allowedPlatforms);
    }
    _bcdEnabled = existing?.bcdEnabled ?? true;
    _randomizeQuestions = existing?.randomizeQuestions ?? false;
    _shuffleChoices = existing?.shuffleChoices ?? false;
    _isOfflineReady = existing?.isOfflineReady ?? false;
    _startsAt = existing?.startsAt;
    _selectedDepartmentId = existing?.departmentId;
    _selectedSemester = existing?.semester;
    _negativeMarkingWeight = existing?.negativeMarkingWeight ?? 0.0;

    _departmentsFuture = _fetchDepartments();
  }

  Future<List<Map<String, dynamic>>> _fetchDepartments() async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>('/departments');
    if (response.data != null && response.data!['departments'] is List) {
      return List<Map<String, dynamic>>.from(response.data!['departments']);
    }
    return [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _courseCodeController.dispose();
    _durationController.dispose();
    _totalMarksController.dispose();
    _passPercentageController.dispose();
    super.dispose();
  }

  Future<void> _pickStartsAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt ?? DateTime.now()),
    );

    if (time == null) return;

    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final description = _descriptionController.text.trim();
    final courseCode = _courseCodeController.text.trim();
    final bloc = context.read<ExamBloc>();

    final event = widget.isEditing
        ? UpdateExam(
            examId: widget.existingExam!.id,
            title: _titleController.text.trim(),
            description: description.isEmpty ? null : description,
            courseCode: courseCode.isEmpty ? null : courseCode,
            durationMinutes: int.parse(_durationController.text),
            totalMarks: double.parse(_totalMarksController.text),
            negativeMarkingWeight: _negativeMarkingWeight,
            passPercentage: double.parse(_passPercentageController.text),
            status: _status,
            allowedPlatforms: _allowedPlatforms.isEmpty ? null : _allowedPlatforms.toList(),
            bcdEnabled: _bcdEnabled,
            randomizeQuestions: _randomizeQuestions,
            shuffleChoices: _shuffleChoices,
            isOfflineReady: _isOfflineReady,
            startsAt: _startsAt?.toIso8601String(),
            departmentId: _selectedDepartmentId,
            semester: _selectedSemester,
          )
        : CreateExam(
            title: _titleController.text.trim(),
            description: description.isEmpty ? null : description,
            courseCode: courseCode.isEmpty ? null : courseCode,
            durationMinutes: int.parse(_durationController.text),
            totalMarks: double.parse(_totalMarksController.text),
            negativeMarkingWeight: _negativeMarkingWeight,
            passPercentage: double.parse(_passPercentageController.text),
            status: _status,
            allowedPlatforms: _allowedPlatforms.isEmpty ? null : _allowedPlatforms.toList(),
            bcdEnabled: _bcdEnabled,
            randomizeQuestions: _randomizeQuestions,
            shuffleChoices: _shuffleChoices,
            isOfflineReady: _isOfflineReady,
            startsAt: _startsAt?.toIso8601String(),
            departmentId: _selectedDepartmentId,
            semester: _selectedSemester,
          );

    bloc.add(event);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => ExamBloc(repository: ExamRepository())),
        BlocProvider(
          create: (context) {
            final bloc = ExamQuestionConfigurationBloc(repository: ExamRepository());
            if (widget.isEditing) {
              bloc.add(LoadConfigurations(widget.existingExam!.id));
            }
            return bloc;
          },
        ),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<ExamBloc, ExamState>(
            listener: (context, state) {
              if (state is ExamOperationSuccess) {
                Navigator.of(context).pop(true);
              } else if (state is ExamError) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(state.message)));
              }
            },
          ),
          BlocListener<ExamQuestionConfigurationBloc, ExamQuestionConfigurationState>(
            listener: (context, state) {
              if (state is ExamQuestionConfigurationSaved) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('Configuration saved successfully.')));
              } else if (state is ExamQuestionConfigurationError) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(state.message)));
              }
            },
          ),
        ],
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.isEditing ? 'Edit Exam' : 'Add Exam'),
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
                  child: Column(
                    children: [
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(labelText: 'Title'),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Title is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: _departmentsFuture,
                              builder: (context, snapshot) {
                                final depts = snapshot.data ?? [];
                                return DropdownButtonFormField<int>(
                                  initialValue: _selectedDepartmentId,
                                  decoration: const InputDecoration(labelText: 'Department'),
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('No Department (Global)')),
                                    for (final dept in depts)
                                      DropdownMenuItem(
                                        value: dept['id'] as int,
                                        child: Text(dept['name'] as String),
                                      ),
                                  ],
                                  onChanged: (val) => setState(() => _selectedDepartmentId = val),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              initialValue: _selectedSemester,
                              decoration: const InputDecoration(labelText: 'Semester'),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('N/A')),
                                for (var i = 1; i <= 8; i++)
                                  DropdownMenuItem(value: i, child: Text('Semester $i')),
                              ],
                              onChanged: (val) => setState(() => _selectedSemester = val),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Starts At'),
                              subtitle: Text(
                                _startsAt != null
                                    ? DateFormat('MMM dd, yyyy - hh:mm a').format(_startsAt!)
                                    : 'Not scheduled (Immediate)',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.calendar_today),
                                onPressed: _pickStartsAt,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 3,
                              decoration:
                                  const InputDecoration(labelText: 'Description'),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _courseCodeController,
                              decoration:
                                  const InputDecoration(labelText: 'Course Code'),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _durationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duration (minutes)',
                              ),
                              validator: (value) {
                                final n = int.tryParse(value ?? '');
                                if (n == null || n < 1) {
                                  return 'Enter a valid duration';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _totalMarksController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration:
                                  const InputDecoration(labelText: 'Total Marks'),
                              validator: (value) {
                                final n = double.tryParse(value ?? '');
                                if (n == null || n < 0) {
                                  return 'Enter a valid number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<double>(
                              initialValue: _negativeMarkingWeight,
                              decoration: const InputDecoration(
                                labelText: 'Negative Marking Weight',
                                helperText: 'Proportion of question marks deducted for incorrect answers',
                              ),
                              items: [
                                for (final val in _negativeMarkingOptions)
                                  DropdownMenuItem(
                                    value: val, 
                                    child: Text(val == 0 ? 'Disabled' : '-${val.toStringAsFixed(2)}')
                                  ),
                              ],
                              onChanged: (val) => setState(() => _negativeMarkingWeight = val!),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passPercentageController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Pass Percentage (%)',
                                hintText: 'e.g. 50.0',
                              ),
                              validator: (value) {
                                final n = double.tryParse(value ?? '');
                                if (n == null || n < 0 || n > 100) {
                                  return 'Enter a value between 0 and 100';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _status,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Status'),
                              items: [
                                for (final status in _statuses)
                                  DropdownMenuItem(
                                    value: status,
                                    child: Text(
                                      _titleCase(status),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _status = value);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Allowed Platforms',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Leave empty to allow all platforms.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                for (final platform in _platforms)
                                  SizedBox(
                                    width: 150,
                                    child: CheckboxListTile(
                                      title: Text(_titleCase(platform)),
                                      value: _allowedPlatforms.contains(platform),
                                      onChanged: (selected) {
                                        setState(() {
                                          if (selected == true) {
                                            _allowedPlatforms.add(platform);
                                          } else {
                                            _allowedPlatforms.remove(platform);
                                          }
                                        });
                                      },
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      controlAffinity: ListTileControlAffinity.leading,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('Behavioral Cheating Detection'),
                              subtitle: const Text('Enable interaction telemetry and risk scoring.'),
                              value: _bcdEnabled,
                              onChanged: (value) => setState(() => _bcdEnabled = value),
                              contentPadding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              title: const Text('Random Question Ordering'),
                              subtitle: const Text('Display questions in a different order for each candidate.'),
                              value: _randomizeQuestions,
                              onChanged: (value) => setState(() => _randomizeQuestions = value),
                              contentPadding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              title: const Text('Choice Shuffling'),
                              subtitle: const Text('Shuffle MCQ and True/False choices for every question.'),
                              value: _shuffleChoices,
                              onChanged: (value) => setState(() => _shuffleChoices = value),
                              contentPadding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              title: const Text('Offline Ready'),
                              subtitle: const Text('Pre-cache all question models, assets, and schema mappings on candidate devices.'),
                              value: _isOfflineReady,
                              onChanged: (value) => setState(() => _isOfflineReady = value),
                              contentPadding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 24),
                            BlocBuilder<ExamBloc, ExamState>(
                              builder: (context, state) {
                                final submitting = state is ExamLoading;
                                return FilledButton(
                                  onPressed: submitting ? null : () => _submit(context),
                                  child: submitting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child:
                                              CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Text(
                                          widget.isEditing ? 'Save Changes' : 'Create Exam',
                                        ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      if (widget.isEditing)
                        QuestionConfigurationBuilder(examId: widget.existingExam!.id),
                    ],
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
