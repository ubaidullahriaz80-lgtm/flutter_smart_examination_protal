import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/kiosk/focus_monitor.dart';
import '../../../core/kiosk/kiosk_service.dart';
import '../../../data/models/exam_model.dart';
import '../../../data/models/question_model.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../../data/repositories/exam_session_repository.dart';
import '../../../data/repositories/local_session_repository.dart';
import '../bloc/exam_delivery_bloc.dart';
import '../bloc/exam_delivery_event.dart';
import '../bloc/exam_delivery_state.dart';
import 'exam_submission_confirmation_view.dart';

/// Candidate-facing exam delivery screen.
class ExamDeliveryView extends StatefulWidget {
  const ExamDeliveryView({super.key, required this.examId});

  final int examId;

  @override
  State<ExamDeliveryView> createState() => _ExamDeliveryViewState();
}

class _ExamDeliveryViewState extends State<ExamDeliveryView> {
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _questionKeys = [];

  final Map<int, TextEditingController> _textControllers = {};
  final FocusMonitor _focusMonitor = FocusMonitor();
  StreamSubscription<FocusEvent>? _focusSubscription;

  @override
  void initState() {
    super.initState();
    _focusMonitor.start();
  }

  @override
  void dispose() {
    _focusSubscription?.cancel();
    _focusMonitor.dispose();
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _setupFocusMonitor(BuildContext context, bool bcdEnabled) {
    _focusSubscription?.cancel();
    if (!bcdEnabled) return;

    _focusSubscription = _focusMonitor.onFocusChange.listen((event) {
      final bloc = context.read<ExamDeliveryBloc>();
      switch (event) {
        case FocusEvent.lost:
          bloc.add(const HandleProctorViolation('WindowFocusLoss'));
        case FocusEvent.tabSwitched:
          bloc.add(const HandleProctorViolation('TabSwitchAttempt'));
        case FocusEvent.regained:
          bloc.add(const HandleProctorViolation('focus_regained'));
      }
    });
  }

  void _ensureQuestionKeys(int count) {
    if (_questionKeys.length != count) {
      _questionKeys = List.generate(count, (_) => GlobalKey());
    }
  }

  Future<void> _scrollToQuestion(int index) async {
    if (_questionKeys.isEmpty || index >= _questionKeys.length) return;
    final questionContext = _questionKeys[index].currentContext;
    if (questionContext != null) {
      await Scrollable.ensureVisible(
        questionContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  TextEditingController _textControllerFor(int questionId, String initialValue) {
    return _textControllers.putIfAbsent(
      questionId,
      () => TextEditingController(text: initialValue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExamDeliveryBloc(
        examRepository: ExamRepository(),
        sessionRepository: ExamSessionRepository(),
        localSessionRepository: LocalSessionRepository(),
      )..add(StartExamSession(widget.examId)),
      child: BlocListener<ExamDeliveryBloc, ExamDeliveryState>(
        listenWhen: (prev, curr) =>
            curr is ExamDeliverySubmitted ||
            (prev is ExamDeliveryActive &&
                curr is ExamDeliveryActive &&
                prev.currentIndex != curr.currentIndex) ||
            (curr is ExamDeliveryActive && prev is! ExamDeliveryActive),
        listener: (context, state) {
          if (state is ExamDeliverySubmitted) {
            KioskService.exitKioskMode();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ExamSubmissionConfirmationView(result: state.result),
              ),
            );
          } else if (state is ExamDeliveryActive) {
            _setupFocusMonitor(context, state.exam.bcdEnabled);
            _scrollToQuestion(state.currentIndex);
            if (!state.isExpired) {
              KioskService.enterKioskMode();
            }
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Exam'),
            actions: [
              _BcdStatusChip(),
              _TimerDisplay(),
            ],
          ),
          body: BlocBuilder<ExamDeliveryBloc, ExamDeliveryState>(
            builder: (context, state) {
              if (state is ExamDeliveryLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is ExamDeliveryError) {
                return _ErrorView(
                  message: state.message,
                  onRetry: () {
                    context.read<ExamDeliveryBloc>().add(StartExamSession(widget.examId));
                  },
                );
              }

              if (state is ExamDeliveryActive) {
                final questions = state.displayQuestions ?? state.exam.questions;
                _ensureQuestionKeys(questions.length);

                return Column(
                  children: [
                    if (state.errorMessage != null)
                      _SessionErrorBanner(message: state.errorMessage!)
                    else if (state.isExpired)
                      const _TimeExpiredBanner(),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: ListView(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            children: [
                              _ExamSummaryCard(exam: state.exam),
                              const SizedBox(height: 20),
                              if (questions.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 32),
                                    child: Text(
                                      'No questions available for this exam.',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                )
                              else
                                for (var i = 0; i < questions.length; i++) ...[
                                  _QuestionCard(
                                    key: _questionKeys[i],
                                    index: i,
                                    question: questions[i],
                                    selectedOption: state.answers[questions[i].id],
                                    isSaving: state.savingQuestionIds.contains(questions[i].id),
                                    saveFailed: state.failedQuestionIds.contains(questions[i].id),
                                    isExpired: state.isExpired,
                                    shuffledOptions: state.shuffledOptions[questions[i].id],
                                    textController: {
                                      'short_answer',
                                      'essay',
                                      'code_snippet',
                                    }.contains(questions[i].questionType)
                                        ? _textControllerFor(questions[i].id, state.answers[questions[i].id] ?? '')
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (questions.isNotEmpty)
                      _QuestionNavBar(
                        currentIndex: state.currentIndex,
                        totalQuestions: questions.length,
                        submitting: state.isSubmitting,
                      ),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

class _TimerDisplay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocSelector<ExamDeliveryBloc, ExamDeliveryState, (Duration, bool)>(
      selector: (state) {
        if (state is ExamDeliveryActive) {
          return (state.remainingTime, state.isExpired);
        }
        return (Duration.zero, false);
      },
      builder: (context, data) {
        final remaining = data.$1;
        final expired = data.$2;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: expired ? Theme.of(context).colorScheme.error : null,
                ),
                const SizedBox(width: 6),
                Text(
                  expired ? 'Time expired' : _formatDuration(remaining),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: expired ? Theme.of(context).colorScheme.error : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _BcdStatusChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocSelector<ExamDeliveryBloc, ExamDeliveryState, (int, String)>(
      selector: (state) {
        if (state is ExamDeliveryActive) {
          return (state.suspicionScore, state.suspicionStatus);
        }
        return (0, 'normal');
      },
      builder: (context, data) {
        final score = data.$1;
        final status = data.$2;
        if (score == 0) return const SizedBox.shrink();

        final color = status == 'highly_suspicious'
            ? Theme.of(context).colorScheme.error
            : status == 'suspicious'
                ? Colors.orange
                : null;

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Chip(
            avatar: Icon(Icons.visibility_outlined, size: 16, color: color),
            label: Text(status.toUpperCase()),
            labelStyle: const TextStyle(fontSize: 10),
            visualDensity: VisualDensity.compact,
          ),
        );
      },
    );
  }
}

class _ExamSummaryCard extends StatelessWidget {
  const _ExamSummaryCard({required this.exam});
  final ExamModel exam;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exam.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (exam.description != null) ...[
              const SizedBox(height: 8),
              Text(exam.description!),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              children: [
                _InfoItem(icon: Icons.timer_outlined, label: '${exam.durationMinutes} min'),
                _InfoItem(icon: Icons.grade_outlined, label: '${exam.totalMarks} marks'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.index,
    required this.question,
    required this.selectedOption,
    required this.isSaving,
    required this.saveFailed,
    required this.isExpired,
    this.shuffledOptions,
    this.textController,
  });

  final int index;
  final QuestionModel question;
  final String? selectedOption;
  final bool isSaving;
  final bool saveFailed;
  final bool isExpired;
  final List<String>? shuffledOptions;
  final TextEditingController? textController;

  @override
  Widget build(BuildContext context) {
    final isMcq = question.questionType == 'mcq';
    final isTrueFalse = question.questionType == 'true_false';
    final isMatching = question.questionType == 'matching';
    final isFreeText = textController != null;

    final options = shuffledOptions ?? (isTrueFalse ? ['True', 'False'] : question.options);

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
                    'Q${index + 1}. ${question.questionText}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (isSaving)
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (isMcq || isTrueFalse)
              Column(
                children: [
                  for (final option in options)
                    RadioListTile<String>(
                      title: Text(option),
                      value: option,
                      groupValue: selectedOption,
                      onChanged: isExpired
                          ? null
                          : (val) {
                              if (val != null) {
                                context.read<ExamDeliveryBloc>().add(SaveAnswer(questionId: question.id, option: val));
                              }
                            },
                    ),
                ],
              )
            else if (isMatching)
              _MatchingWidget(question: question, selectedJson: selectedOption, isExpired: isExpired)
            else if (isFreeText)
              TextField(
                controller: textController,
                enabled: !isExpired,
                maxLines: 5,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Your answer...'),
                onChanged: (val) {
                  context.read<ExamDeliveryBloc>().add(SaveAnswer(questionId: question.id, option: val));
                },
              ),
            if (saveFailed)
              const Text('Failed to save answer', style: TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _MatchingWidget extends StatelessWidget {
  const _MatchingWidget({required this.question, required this.selectedJson, required this.isExpired});
  final QuestionModel question;
  final String? selectedJson;
  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    final selections = selectedJson != null ? jsonDecode(selectedJson!) as Map<String, dynamic> : {};
    final rightChoices = question.matchingPairs.map((p) => p.right).toList();

    return Column(
      children: [
        for (final pair in question.matchingPairs)
          Row(
            children: [
              Expanded(child: Text(pair.left)),
              const Icon(Icons.arrow_forward),
              Expanded(
                child: DropdownButton<String>(
                  value: selections[pair.left],
                  items: rightChoices.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: isExpired
                      ? null
                      : (val) {
                          if (val != null) {
                            final updated = Map<String, dynamic>.from(selections)..[pair.left] = val;
                            context
                                .read<ExamDeliveryBloc>()
                                .add(SaveAnswer(questionId: question.id, option: jsonEncode(updated)));
                          }
                        },
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _QuestionNavBar extends StatelessWidget {
  const _QuestionNavBar({
    required this.currentIndex,
    required this.totalQuestions,
    required this.submitting,
  });

  final int currentIndex;
  final int totalQuestions;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ExamDeliveryBloc>();
    return Material(
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: currentIndex > 0 ? () => bloc.add(SelectQuestion(currentIndex - 1)) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Question ${currentIndex + 1} of $totalQuestions'),
                  IconButton(
                    onPressed: currentIndex < totalQuestions - 1 ? () => bloc.add(SelectQuestion(currentIndex + 1)) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: submitting ? null : () => _showConfirm(context),
                  child: Text(submitting ? 'Submitting...' : 'Submit Exam'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Exam?'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<ExamDeliveryBloc>().add(const SubmitExam());
              },
              child: const Text('Submit')),
        ],
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
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}

class _SessionErrorBanner extends StatelessWidget {
  const _SessionErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red[100],
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class _TimeExpiredBanner extends StatelessWidget {
  const _TimeExpiredBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.orange[100],
      padding: const EdgeInsets.all(8),
      child: const Row(
        children: [
          Icon(Icons.timer_off_outlined, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(child: Text('Time expired. Review your answers and submit.')),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
