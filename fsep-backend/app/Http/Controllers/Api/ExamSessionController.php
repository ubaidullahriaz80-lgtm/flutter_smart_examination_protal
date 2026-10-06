<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\AnswerResource;
use App\Http\Resources\ExamSessionResource;
use App\Jobs\ProcessBehavioralTelemetry;
use App\Models\Answer;
use App\Models\BehaviorEvent;
use App\Models\BehavioralAlert;
use App\Models\BehavioralReviewAction;
use App\Models\BehavioralRiskScore;
use App\Models\Exam;
use App\Models\ExamSession;
use App\Http\Resources\ResultResource;
use App\Models\Question;
use App\Models\User;
use App\Services\BehavioralService;
use App\Services\FcmService;
use App\Services\GradingService;
use App\Services\LearningAnalyticsService;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * Controller for managing candidate exam delivery sessions and answer persistence.
 */
class ExamSessionController extends Controller
{
    public function startOrResume(Request $request, Exam $exam)
    {
        $user = $request->user();

        if ($user->role === 'candidate') {
            if ($exam->department_id !== $user->department_id || $exam->semester !== $user->semester) {
                return response()->json([
                    'message' => 'This exam is not available for your department or semester.',
                ], 403);
            }

            if ($exam->starts_at && $exam->starts_at->isFuture()) {
                return response()->json([
                    'message' => 'This exam is locked until ' . $exam->starts_at->format('M j, Y, g:i A'),
                ], 403);
            }
        }

        $startedAt = now();

        $session = ExamSession::firstOrCreate(
            [
                'exam_id' => $exam->id,
                'candidate_id' => $request->user()->id,
            ],
            [
                'status' => 'in_progress',
                'started_at' => $startedAt,
                'expires_at' => $startedAt->copy()->addMinutes($exam->duration_minutes),
            ],
        );

        if ($session->status === 'in_progress' && $session->isExpired()) {
            $session->status = 'expired';
            $session->save();
        }

        $session->load('answers');

        return response()->json([
            'session' => new ExamSessionResource($session),
        ]);
    }

    public function saveAnswer(Request $request, ExamSession $session, Question $question)
    {
        if ($session->candidate_id !== $request->user()->id) {
            return response()->json([
                'message' => 'This action is unauthorized.',
            ], 403);
        }

        if ($question->exam_id !== $session->exam_id) {
            return response()->json([
                'message' => 'This question does not belong to this exam session.',
            ], 422);
        }

        if ($question->review_status !== 'approved') {
            return response()->json([
                'message' => 'This question is not available for this exam session.',
            ], 422);
        }

        if ($session->status !== 'in_progress') {
            return response()->json([
                'message' => 'This exam session is no longer active.',
            ], 422);
        }

        if ($session->isExpired()) {
            $session->status = 'expired';
            $session->save();

            return response()->json([
                'message' => 'This exam session has expired.',
            ], 422);
        }

        $validated = $request->validate([
            'selected_option' => ['required', 'string', 'max:5000'],
        ]);

        if ($question->question_type === 'mcq' && !empty($question->options) &&
            !in_array($validated['selected_option'], $question->options, true)) {
            return response()->json([
                'message' => 'The selected option is not valid for this question.',
                'errors' => [
                    'selected_option' => ['The selected option is not valid for this question.'],
                ],
            ], 422);
        }

        $answer = Answer::updateOrCreate(
            [
                'exam_session_id' => $session->id,
                'question_id' => $question->id,
            ],
            [
                'selected_option' => $validated['selected_option'],
            ],
        );

        return response()->json([
            'answer' => new AnswerResource($answer),
        ]);
    }

    public function syncAnswers(Request $request, ExamSession $session)
    {
        if ($session->candidate_id !== $request->user()->id) {
            return response()->json([
                'message' => 'This action is unauthorized.',
            ], 403);
        }

        $validated = $request->validate([
            'answers' => ['required', 'array', 'min:1', 'max:100'],
            'answers.*.question_id' => ['required', 'integer'],
            'answers.*.selected_option' => ['required', 'string', 'max:5000'],
            'answers.*.client_updated_at' => ['nullable', 'date'],
        ]);

        $sessionConflictMessage = null;
        if ($session->status !== 'in_progress') {
            $sessionConflictMessage = 'This exam session is no longer active.';
        } elseif ($session->isExpired()) {
            $session->status = 'expired';
            $session->save();
            $sessionConflictMessage = 'This exam session has expired.';
        }

        $results = [];

        foreach ($validated['answers'] as $item) {
            $questionId = $item['question_id'];

            if ($sessionConflictMessage !== null) {
                $results[] = $this->conflictResult($questionId, 'CONFLICT_SESSION_CLOSED', $sessionConflictMessage);
                continue;
            }

            $question = Question::find($questionId);

            if ($question === null || $question->exam_id !== $session->exam_id) {
                $results[] = $this->conflictResult(
                    $questionId,
                    'VALIDATION_FAILED',
                    'This question does not belong to this exam session.',
                );
                continue;
            }

            if ($question->review_status !== 'approved') {
                $results[] = $this->conflictResult(
                    $questionId,
                    'VALIDATION_FAILED',
                    'This question is not available for this exam session.',
                );
                continue;
            }

            if ($question->question_type === 'mcq' && !empty($question->options) &&
                !in_array($item['selected_option'], $question->options, true)) {
                $results[] = $this->conflictResult(
                    $questionId,
                    'VALIDATION_FAILED',
                    'The selected option is not valid for this question.',
                );
                continue;
            }

            $existingAnswer = Answer::where('exam_session_id', $session->id)
                ->where('question_id', $question->id)
                ->first();

            if ($existingAnswer !== null && isset($item['client_updated_at'])) {
                $clientUpdatedAt = Carbon::parse($item['client_updated_at']);
                if ($existingAnswer->updated_at->greaterThan($clientUpdatedAt)) {
                    $results[] = $this->conflictResult(
                        $questionId,
                        'SERVER_VERSION_AHEAD',
                        'A newer answer for this question already exists on the server.',
                    );
                    continue;
                }
            }

            $answer = Answer::updateOrCreate(
                [
                    'exam_session_id' => $session->id,
                    'question_id' => $question->id,
                ],
                [
                    'selected_option' => $item['selected_option'],
                ],
            );

            $results[] = [
                'question_id' => $questionId,
                'status' => 'synced',
                'answer_id' => $answer->id,
            ];
        }

        return response()->json(['results' => $results]);
    }

    private function conflictResult(int $questionId, string $code, string $message): array
    {
        return [
            'question_id' => $questionId,
            'status' => 'conflict',
            'code' => $code,
            'message' => $message,
        ];
    }

    public function submit(Request $request, ExamSession $session, GradingService $grading, FcmService $fcm, LearningAnalyticsService $analytics)
    {
        if ($session->candidate_id !== $request->user()->id) {
            return response()->json([
                'message' => 'This action is unauthorized.',
            ], 403);
        }

        if ($session->status === 'submitted') {
            return response()->json([
                'message' => 'This exam session has already been submitted.',
            ], 422);
        }

        if (!in_array($session->status, ['in_progress', 'expired'], true)) {
            return response()->json([
                'message' => 'This exam session cannot be submitted.',
            ], 422);
        }

        if ($session->status === 'in_progress' && $session->isExpired()) {
            $session->status = 'expired';
        }

        $result = DB::transaction(function () use ($session, $grading, $analytics) {
            $session->status = 'submitted';
            $session->submitted_at = now();
            $session->save();

            $res = $grading->gradeSession($session);

            $analytics->generateReport($session);

            return $res;
        });

        $scoreText = round($result->total_score, 2) . " / " . round($result->max_score, 2);
        $title = "Evaluation Published: {$session->exam->title}";
        $body = "Your result for '{$session->exam->title}' is ready. Final Score: {$scoreText}. Tap to view your Learning Gap Report.";

        $fcm->sendToUser($session->candidate, $title, $body, [
            'type' => 'exam_result',
            'session_id' => (string) $session->id,
            'exam_id' => (string) $session->exam_id,
            'score' => (string) $result->total_score,
            'max_score' => (string) $result->max_score,
        ]);

        $session->load('answers');

        return response()->json([
            'session' => new ExamSessionResource($session),
            'result' => new ResultResource($result),
        ]);
    }

    private function suspicionSummary(ExamSession $session, BehavioralService $service): array
    {
        $risk = BehavioralRiskScore::where('exam_session_id', $session->id)->first();

        if (!$risk) {
            return [
                'suspicion_score' => 0,
                'suspicion_status' => 'low',
            ];
        }

        return [
            'suspicion_score' => $risk->risk_score,
            'suspicion_status' => $risk->risk_band,
            'event_breakdown' => $risk->event_breakdown,
        ];
    }

    public function behavioralDashboard(Request $request, Exam $exam)
    {
        if ($request->user()->role === 'examiner' && $exam->created_by !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized.'], 403);
        }

        return response()->stream(function () use ($exam) {
            $lastId = BehavioralRiskScore::whereIn('exam_session_id', $exam->sessions()->pluck('id'))
                ->max('id') ?? 0;

            echo ": heartbeat\n\n";
            if (ob_get_level() > 0) ob_flush();
            flush();

            $maxIterations = 5;
            $iterations = 0;

            while ($iterations < $maxIterations) {
                if (connection_aborted()) break;

                $updates = BehavioralRiskScore::with(['session.candidate', 'session.behaviorEvents' => function($q) {
                    $q->with('reviewAction')->latest()->limit(5);
                }])
                    ->whereIn('exam_session_id', $exam->sessions()->pluck('id'))
                    ->where('id', '>', $lastId)
                    ->orderBy('id', 'asc')
                    ->get();

                foreach ($updates as $update) {
                    $isAlert = BehavioralAlert::where('exam_session_id', $update->exam_session_id)
                        ->where('triggered_at', '>=', $update->computed_at->subSeconds(5))
                        ->exists();

                    $payload = [
                        'session_id' => $update->exam_session_id,
                        'candidate_id' => $update->session->candidate_id,
                        'candidate_name' => $update->session->candidate->name,
                        'risk_score' => $update->risk_score,
                        'risk_band' => $update->risk_band,
                        'computed_at' => $update->computed_at,
                        'is_alert' => $isAlert,
                        'event_breakdown' => $update->event_breakdown,
                        'latest_events' => $update->session->behaviorEvents->map(fn($e) => [
                            'id' => $e->id,
                            'type' => $e->event_type,
                            'ts' => $e->event_timestamp ?? $e->created_at,
                            'review_action' => $e->reviewAction?->action,
                        ]),
                    ];

                    echo "data: " . json_encode($payload) . "\n\n";
                    $lastId = $update->id;
                }

                if ($updates->isNotEmpty()) {
                    if (ob_get_level() > 0) ob_flush();
                    flush();
                }

                sleep(2);
                $iterations++;
            }
        }, 200, [
            'Content-Type' => 'text/event-stream',
            'Cache-Control' => 'no-cache',
            'Connection' => 'keep-alive',
            'X-Accel-Buffering' => 'no',
        ]);
    }

    public function activeSessions(Request $request, BehavioralService $service)
    {
        $sessions = ExamSession::with(['candidate', 'exam'])
            ->orderByDesc('started_at')
            ->get();

        return response()->json([
            'sessions' => $sessions->map(fn (ExamSession $session) => [
                'session_id' => $session->id,
                'candidate_name' => $session->candidate->name,
                'candidate_email' => $session->candidate->email,
                'exam_id' => $session->exam_id,
                'exam_title' => $session->exam->title,
                'course_code' => $session->exam->course_code,
                'status' => $session->status,
                'started_at' => $session->started_at,
                'submitted_at' => $session->submitted_at,
                ...$this->suspicionSummary($session, $service),
            ])->values(),
        ]);
    }

    public function behavioralAlerts(Request $request, Exam $exam)
    {
        if ($request->user()->role === 'examiner' && $exam->created_by !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized.'], 403);
        }

        $alerts = BehavioralAlert::with('candidate')
            ->whereIn('exam_session_id', $exam->sessions()->pluck('id'))
            ->latest('triggered_at')
            ->get();

        return response()->json([
            'alerts' => $alerts->map(fn ($alert) => [
                'candidate_id' => $alert->candidate_id,
                'candidate_name' => $alert->candidate->name,
                'risk_score' => $alert->risk_score,
                'risk_band' => $alert->risk_band,
                'triggered_at' => $alert->triggered_at,
            ]),
        ]);
    }

    public function reviewBehavioralEvent(Request $request)
    {
        $validated = $request->validate([
            'event_id' => ['required', 'exists:behavior_events,id'],
            'action' => ['required', Rule::in(['Reviewed', 'Escalated', 'Dismissed'])],
            'note' => ['nullable', 'string', 'max:1000'],
        ]);

        $event = BehaviorEvent::findOrFail($validated['event_id']);

        $action = BehavioralReviewAction::updateOrCreate(
            ['event_id' => $event->id],
            [
                'invigilator_id' => $request->user()->id,
                'action' => $validated['action'],
                'note' => $validated['note'],
                'actioned_at' => now(),
            ]
        );

        return response()->json([
            'status' => 'recorded',
            'action' => $action->action,
        ]);
    }

    public function syncBehaviorEvents(Request $request, ExamSession $session, FcmService $fcm, BehavioralService $service)
    {
        if ($session->candidate_id !== $request->user()->id) {
            return response()->json([
                'message' => 'This action is unauthorized.',
            ], 403);
        }

        if (!$session->exam->bcd_enabled) {
            return response()->json([
                'message' => 'Behavioral Cheating Detection is disabled for this exam.',
            ], 422);
        }

        $validated = $request->validate([
            'events' => ['required', 'array', 'min:1', 'max:500'],
            'events.*.client_uuid' => ['required', 'string', 'max:64'],
            'events.*.event_type' => [
                'required',
                'string',
                Rule::in(array_keys($service->getEventPoints())),
            ],
            'events.*.metadata' => ['nullable', 'array'],
            'events.*.occurred_at' => ['required', 'date'],
        ]);

        $sessionActive = $session->status === 'in_progress' && !$session->isExpired();

        $results = [];
        foreach ($validated['events'] as $item) {
            $uuid = $item['client_uuid'];

            if (!$sessionActive) {
                $results[] = [
                    'client_uuid' => $uuid,
                    'status' => 'conflict',
                    'code' => 'CONFLICT_SESSION_CLOSED',
                    'message' => 'This exam session is no longer active.',
                ];
                continue;
            }

            $event = BehaviorEvent::firstOrCreate(
                ['client_uuid' => $uuid],
                [
                    'exam_session_id' => $session->id,
                    'candidate_id' => $session->candidate_id,
                    'event_type' => $item['event_type'],
                    'severity' => $service->deriveSeverity($item['event_type']),
                    'suspicion_points' => $service->getEventPoints()[$item['event_type']],
                    'metadata' => $item['metadata'] ?? null,
                    'event_timestamp' => Carbon::parse($item['occurred_at']),
                    'created_at' => Carbon::parse($item['occurred_at']),
                ]
            );

            $results[] = [
                'client_uuid' => $uuid,
                'status' => 'synced',
                'event_id' => $event->id,
            ];
        }

        ProcessBehavioralTelemetry::dispatch($session->id);

        $summary = $this->suspicionSummary($session, $service);

        return response()->json([
            'results' => $results,
            ...$summary,
        ]);
    }

    public function recordBehaviorEvent(Request $request, ExamSession $session, FcmService $fcm, BehavioralService $service)
    {
        if ($session->candidate_id !== $request->user()->id) {
            return response()->json([
                'message' => 'This action is unauthorized.',
            ], 403);
        }

        if (!$session->exam->bcd_enabled) {
            return response()->json([
                'message' => 'Behavioral Cheating Detection is disabled for this exam.',
            ], 422);
        }

        if ($session->status !== 'in_progress' || $session->isExpired()) {
            return response()->json([
                'message' => 'This exam session is no longer active.',
            ], 422);
        }

        $validated = $request->validate([
            'event_type' => ['required', 'string', Rule::in(array_keys($service->getEventPoints()))],
            'metadata' => ['nullable', 'array'],
        ]);

        $event = BehaviorEvent::create([
            'exam_session_id' => $session->id,
            'candidate_id' => $session->candidate_id,
            'event_type' => $validated['event_type'],
            'severity' => $service->deriveSeverity($validated['event_type']),
            'suspicion_points' => $service->getEventPoints()[$validated['event_type']],
            'metadata' => $validated['metadata'] ?? null,
            'event_timestamp' => now(),
        ]);

        ProcessBehavioralTelemetry::dispatch($session->id);

        $summary = $this->suspicionSummary($session, $service);

        return response()->json([
            'event' => [
                'event_type' => $event->event_type,
                'suspicion_points' => $event->suspicion_points,
                'occurred_at' => $event->created_at,
            ],
            ...$summary,
        ], 201);
    }

    public function behaviorEvents(Request $request, ExamSession $session, BehavioralService $service)
    {
        $user = $request->user();
        $isOwner = $session->candidate_id === $user->id;
        $isStaff = in_array($user->role, ['examiner', 'system_administrator', 'live_invigilator'], true);

        if (!$isOwner && !$isStaff) {
            return response()->json([
                'message' => 'This action is unauthorized.',
            ], 403);
        }

        $events = $session->behaviorEvents()
            ->with('reviewAction')
            ->orderBy('created_at')
            ->get()
            ->map(fn (BehaviorEvent $event) => [
                'id' => $event->id,
                'event_type' => $event->event_type,
                'suspicion_points' => $event->suspicion_points,
                'occurred_at' => $event->created_at,
                'review_action' => $event->reviewAction?->action,
                'review_note' => $event->reviewAction?->note,
            ]);

        return response()->json([
            'session_id' => $session->id,
            'events' => $events,
            ...$this->suspicionSummary($session, $service),
        ]);
    }

    public function pendingAnswer(Request $request, ExamSession $session, Question $question)
    {
        if ($question->exam_id !== $session->exam_id) {
            return response()->json([
                'message' => 'This question does not belong to this exam session.',
            ], 422);
        }

        $answer = $session->answers()->where('question_id', $question->id)->first();

        if ($answer === null) {
            return response()->json([
                'message' => 'No answer found for this question.',
            ], 404);
        }

        return response()->json([
            'answer' => [
                'session_id' => $session->id,
                'question_id' => $question->id,
                'question_text' => $question->question_text,
                'question_type' => $question->question_type,
                'max_marks' => $question->marks,
                'selected_option' => $answer->selected_option,
                'grading_status' => $answer->grading_status,
                'obtained_marks' => $answer->obtained_marks,
            ],
        ]);
    }

    public function manualGrade(Request $request, ExamSession $session, Question $question, GradingService $grading, FcmService $fcm, LearningAnalyticsService $analytics)
    {
        if ($question->exam_id !== $session->exam_id) {
            return response()->json([
                'message' => 'This question does not belong to this exam session.',
            ], 422);
        }

        $answer = $session->answers()->where('question_id', $question->id)->first();

        if ($answer === null) {
            return response()->json([
                'message' => 'No answer found for this question.',
            ], 404);
        }

        if ($answer->grading_status !== 'pending_manual_review') {
            return response()->json([
                'message' => 'This answer is not pending manual review.',
            ], 422);
        }

        $validated = $request->validate([
            'obtained_marks' => ['required', 'numeric', 'min:0', 'max:' . $question->marks],
        ]);

        $result = DB::transaction(function () use ($answer, $validated, $session, $grading, $analytics) {
            $answer->obtained_marks = $validated['obtained_marks'];
            $answer->grading_status = 'graded';
            $answer->save();

            $updatedResult = $grading->recalculateResult($session);

            $analytics->generateReport($session);

            return $updatedResult;
        });

        $scoreText = round($result->total_score, 2) . " / " . round($result->max_score, 2);
        $title = "Evaluation Updated: {$session->exam->title}";
        $body = "Your result for '{$session->exam->title}' has been finalized after manual review. Final Score: {$scoreText}. Tap to view your Learning Gap Report.";

        $fcm->sendToUser($session->candidate, $title, $body, [
            'type' => 'exam_result',
            'session_id' => (string) $session->id,
            'exam_id' => (string) $session->exam_id,
            'score' => (string) $result->total_score,
            'max_score' => (string) $result->max_score,
        ]);

        return response()->json([
            'answer' => [
                'session_id' => $session->id,
                'question_id' => $question->id,
                'grading_status' => $answer->grading_status,
                'obtained_marks' => $answer->obtained_marks,
            ],
            'result' => new ResultResource($result),
        ]);
    }

    private function deriveSeverity(string $eventType, BehavioralService $service): string
    {
        return $service->deriveSeverity($eventType);
    }
}
