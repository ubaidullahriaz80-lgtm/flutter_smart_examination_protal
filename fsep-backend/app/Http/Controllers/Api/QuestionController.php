<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\AiProviderException;
use App\Http\Controllers\Controller;
use App\Http\Resources\QuestionBankResource;
use App\Jobs\ProcessAiGenerationJob;
use App\Models\AiQuestionGenerationJob;
use App\Models\Question;
use App\Services\AiQuestionGeneratorService;
use App\Services\DocumentParserService;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Throwable;

/**
 * Question Bank management, including the AI Question Generator. Every
 * route on this controller is restricted to the examiner role (see
 * routes/api.php) — the question-authoring role. Candidates must never
 * reach these routes.
 */
class QuestionController extends Controller
{
    private const DIFFICULTIES = ['easy', 'medium', 'hard'];
    private const BLOOM_LEVELS = ['remember', 'understand', 'apply', 'analyze', 'evaluate', 'create'];
    /**
     * All question types the Question Bank (manual create/edit) supports.
     * Deliberately wider than AI_GENERATABLE_TYPES below — matching and
     * code_snippet are manual-entry/manual-review only (see class docs on
     * validatedQuestionData() and GradingService); the AI Question
     * Generator's Gemini prompt/schema was never built for either, so it
     * must keep validating against the narrower list, not this one.
     */
    private const TYPES = ['mcq', 'true_false', 'short_answer', 'essay', 'matching', 'code_snippet'];

    private const AI_GENERATABLE_TYPES = ['mcq', 'true_false', 'short_answer', 'essay'];
    private const REVIEW_STATUSES = ['pending', 'approved', 'rejected'];

    /**
     * POST /api/questions/generate
     *
     * Calls the AI provider (once per selected question type) and returns
     * validated, structured candidate questions for preview. Nothing is
     * saved here — saving is a separate, explicit step (store()) so
     * generated output always goes through review first.
     *
     * Accepts either the original single-value fields (`exam_id`,
     * `question_type`) or the new multi-select arrays (`exam_ids`,
     * `question_types`) — both work, so the original single-exam/
     * single-type request shape still behaves exactly as before.
     * AiQuestionGeneratorService itself is unchanged: it already only
     * ever generates one question_type per call and knows nothing about
     * exam_id, so multi-exam/multi-type support lives entirely here, as
     * a thin loop + a simple deterministic distribution.
     */
    public function generate(Request $request, AiQuestionGeneratorService $generator)
    {
        $validated = $request->validate([
            'exam_id' => ['sometimes', 'integer', 'exists:exams,id'],
            'exam_ids' => ['sometimes', 'array', 'min:1'],
            'exam_ids.*' => ['integer', 'distinct', 'exists:exams,id'],
            'question_type' => ['sometimes', 'string', Rule::in(self::AI_GENERATABLE_TYPES)],
            'question_types' => ['sometimes', 'array', 'min:1'],
            'question_types.*' => ['string', 'distinct', Rule::in(self::AI_GENERATABLE_TYPES)],
            'topic' => ['required', 'string', 'max:255'],
            'difficulty' => ['required', 'string', Rule::in(self::DIFFICULTIES)],
            'bloom_taxonomy' => ['required', 'string', Rule::in(self::BLOOM_LEVELS)],
            // Capped to keep generation requests fast and bounded — not an
            // arbitrary restriction, just guarding against wasting AI
            // provider credits on unreasonable batch sizes. This is the
            // total question count for the whole request, split across
            // the selected question types below — not per-type.
            'count' => ['required', 'integer', 'min:1', 'max:10'],
            'marks' => ['required', 'integer', 'min:1', 'max:100'],
        ]);

        $examIds = array_values(array_unique(
            $validated['exam_ids'] ?? (isset($validated['exam_id']) ? [$validated['exam_id']] : []),
        ));
        $questionTypes = array_values(array_unique(
            $validated['question_types'] ?? (isset($validated['question_type']) ? [$validated['question_type']] : []),
        ));

        if (empty($examIds)) {
            return response()->json(['message' => 'Select at least one exam/course.'], 422);
        }

        if (empty($questionTypes)) {
            return response()->json(['message' => 'Select at least one question type.'], 422);
        }

        $countPerType = $this->splitEvenly($validated['count'], count($questionTypes));
        $allQuestions = [];

        try {
            foreach ($questionTypes as $index => $type) {
                $typeCount = $countPerType[$index];
                if ($typeCount < 1) {
                    continue; // more types selected than the requested count
                }

                $generated = $generator->generate([
                    'topic' => $validated['topic'],
                    'question_type' => $type,
                    'difficulty' => $validated['difficulty'],
                    'bloom_taxonomy' => $validated['bloom_taxonomy'],
                    'count' => $typeCount,
                    'marks' => $validated['marks'],
                ]);

                array_push($allQuestions, ...$generated);
            }
        } catch (AiProviderException $e) {
            return response()->json(['message' => $e->getMessage()], 502);
        } catch (Throwable $e) {
            Log::error('Unexpected AI question generation failure', ['error' => $e->getMessage()]);

            return response()->json([
                'message' => 'Question generation failed unexpectedly. Please try again.',
            ], 500);
        }

        $examIdPerQuestion = $this->distributeAcross(count($allQuestions), $examIds);

        return response()->json([
            'questions' => array_map(
                fn (array $q, int $i) => $q + ['exam_id' => $examIdPerQuestion[$i]],
                $allQuestions,
                array_keys($allQuestions),
            ),
        ]);
    }

    /**
     * Splits $total into $groups roughly-equal integer parts — the first
     * (total % groups) groups get one extra, so nothing is dropped when
     * it doesn't divide evenly. Deliberately simple, no weighting.
     *
     * @return array<int, int>
     */
    private function splitEvenly(int $total, int $groups): array
    {
        $base = intdiv($total, $groups);
        $remainder = $total % $groups;

        return array_map(
            fn (int $i) => $base + ($i < $remainder ? 1 : 0),
            range(0, $groups - 1),
        );
    }

    /**
     * Assigns one value from $values to each of $total items, in
     * contiguous chunks sized by splitEvenly() — e.g. 10 items over
     * [examA, examB] -> first 5 items get examA, next 5 get examB.
     *
     * @param  array<int, mixed>  $values
     * @return array<int, mixed>
     */
    private function distributeAcross(int $total, array $values): array
    {
        $counts = $this->splitEvenly($total, count($values));
        $assignment = [];

        foreach ($values as $index => $value) {
            for ($i = 0; $i < $counts[$index]; $i++) {
                $assignment[] = $value;
            }
        }

        return $assignment;
    }

    public function showJob(AiQuestionGenerationJob $job)
    {
        if ($job->examiner_id !== auth()->id()) {
            return response()->json(['message' => 'Unauthorized.'], 403);
        }

        return response()->json([
            'id' => $job->id,
            'status' => $job->status,
            'document_name' => $job->document_name,
            'questions_generated' => $job->questions_generated,
            'questions_approved' => $job->questions_approved,
            'questions_rejected' => $job->questions_rejected,
            'last_error' => $job->last_error,
            'created_at' => $job->created_at,
            'completed_at' => $job->completed_at,
        ]);
    }

    /**
     * POST /api/questions/generate/approve
     *
     * Batch approval or rejection of generated questions.
     */
    public function bulkReview(Request $request)
    {
        $validated = $request->validate([
            'question_ids' => ['required', 'array', 'min:1'],
            'question_ids.*' => ['integer', 'exists:questions,id'],
            'action' => ['required', 'string', Rule::in(['approve', 'reject'])],
            'rejection_reason' => [
                Rule::requiredIf($request->action === 'reject'),
                'nullable',
                'string',
                'max:1000'
            ],
        ]);

        $questions = Question::whereIn('id', $validated['question_ids'])->get();

        // 1. Validate that all questions belong to the same job
        $jobIds = $questions->pluck('generation_job_id')->unique();
        if ($jobIds->count() !== 1 || $jobIds->first() === null) {
            return response()->json(['message' => 'All questions must belong to the same generation job.'], 422);
        }

        $jobId = $jobIds->first();
        $job = AiQuestionGenerationJob::find($jobId);

        // 2. Verify ownership
        if (!$job || $job->examiner_id !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized.'], 403);
        }

        $reviewStatus = $validated['action'] === 'approve' ? 'approved' : 'rejected';
        $approvedCount = 0;
        $rejectedCount = 0;

        DB::transaction(function () use ($questions, $reviewStatus, $validated, $job, &$approvedCount, &$rejectedCount, $request) {
            foreach ($questions as $question) {
                // Only process questions currently in 'pending' status to avoid corrupting counters
                if ($question->review_status !== 'pending') {
                    continue;
                }

                $question->update([
                    'review_status' => $reviewStatus,
                    'reviewed_by' => $request->user()->id,
                    'reviewed_at' => now(),
                    'rejection_reason' => $reviewStatus === 'rejected' ? $validated['rejection_reason'] : null,
                ]);

                if ($reviewStatus === 'approved') {
                    $approvedCount++;
                } else {
                    $rejectedCount++;
                }
            }

            if ($approvedCount > 0) {
                $job->increment('questions_approved', $approvedCount);
            }
            if ($rejectedCount > 0) {
                $job->increment('questions_rejected', $rejectedCount);
            }

            // Trigger job completion logic
            $job->refresh();
            if ($job->status === 'REVIEW_PENDING' &&
                ($job->questions_approved + $job->questions_rejected) >= $job->questions_generated) {
                $job->update(['status' => 'COMPLETED', 'completed_at' => now()]);
            }
        });

        return response()->json([
            'approved_count' => $approvedCount,
            'rejected_count' => $rejectedCount,
            'job_status' => $job->fresh()->status,
        ]);
    }

    /**
     * GET /api/questions/generate/review/{job}
     *
     * Returns all questions generated by a specific job.
     */
    public function reviewQueue(AiQuestionGenerationJob $job)
    {
        if ($job->examiner_id !== auth()->id()) {
            return response()->json(['message' => 'Unauthorized.'], 403);
        }

        $questions = $job->questions()->with('exam:id,course_code')->get();

        return response()->json([
            'questions' => QuestionBankResource::collection($questions),
        ]);
    }

    public function upload(Request $request, DocumentParserService $parser)
    {
        $validated = $request->validate([
            'files' => ['required', 'array', 'min:1', 'max:10'],
            'files.*' => ['file', 'mimes:pdf,txt', 'max:20480'], // 20MB limit
            'exam_ids' => ['required', 'array', 'min:1'],
            'exam_ids.*' => ['integer', 'distinct', 'exists:exams,id'],
            'question_types' => ['required', 'array', 'min:1'],
            'question_types.*' => ['string', 'distinct', Rule::in(self::AI_GENERATABLE_TYPES)],
            'difficulty' => ['required', 'string', Rule::in(self::DIFFICULTIES)],
            'bloom_taxonomy' => ['required', 'string', Rule::in(self::BLOOM_LEVELS)],
            'count' => ['required', 'integer', 'min:1', 'max:50'],
            'marks' => ['required', 'integer', 'min:1', 'max:100'],
        ]);

        $job = AiQuestionGenerationJob::create([
            'examiner_id' => $request->user()->id,
            'status' => 'UPLOADING',
            'exam_ids' => $validated['exam_ids'],
            'params' => [
                'question_types' => $validated['question_types'],
                'difficulty' => $validated['difficulty'],
                'bloom_taxonomy' => $validated['bloom_taxonomy'],
                'count' => $validated['count'],
                'marks' => $validated['marks'],
            ],
        ]);

        $uploadedFileNames = [];

        foreach ($request->file('files') as $file) {
            $originalName = $file->getClientOriginalName();
            // Sanitize filename to prevent directory traversal or weirdness
            $safeName = time() . '_' . preg_replace('/[^a-zA-Z0-9\._-]/', '', $originalName);
            $file->storeAs("private/generation_docs/{$job->id}", $safeName);
            $uploadedFileNames[] = $originalName;
        }

        $job->update([
            'document_name' => implode(', ', $uploadedFileNames),
            'parsing_at' => now(),
        ]);

        // Trigger parsing. In a production app with large docs,
        // parsing should also be a background job.
        $parser->parse($job);

        if ($job->status === 'GENERATING') {
            $job->update(['generating_at' => now()]);
            ProcessAiGenerationJob::dispatch($job->id);
        }

        return response()->json([
            'message' => 'Documents processed successfully. AI generation started in the background.',
            'job_id' => $job->id,
            'status' => $job->status,
            'error' => $job->last_error,
        ], 201);
    }

    /**
     * GET /api/questions?exam_id=
     */
    public function index(Request $request)
    {
        $user = $request->user();
        $query = Question::with('exam:id,course_code');

        if ($user->role === 'examiner') {
            $query->whereHas('exam', function ($q) use ($user) {
                $q->where('department_id', $user->department_id);
            });
        }

        if ($request->filled('exam_id')) {
            $query->where('exam_id', $request->integer('exam_id'));
        }

        return response()->json([
            'questions' => QuestionBankResource::collection($query->latest()->get()),
        ]);
    }

    /**
     * POST /api/questions
     *
     * Saves a question — generated-and-reviewed or manually authored —
     * into the existing Question Bank. review_status is always forced to
     * "pending" here regardless of client input: nothing skips review by
     * being saved.
     */
    public function store(Request $request)
    {
        $validated = $this->validatedQuestionData($request);

        $question = Question::create($validated + [
            'created_by' => $request->user()->id,
            'review_status' => 'pending',
        ]);
        $question->load('exam:id,course_code');

        return response()->json([
            'question' => new QuestionBankResource($question),
        ], 201);
    }

    /**
     * PUT /api/questions/{question}
     *
     * Edits a question's content and/or moves it through the existing
     * review_status workflow (pending/approved/rejected).
     */
    public function update(Request $request, Question $question)
    {
        $user = $request->user();

        // Examiner department authorization
        if ($user->role === 'examiner' && $question->exam->department_id !== $user->department_id) {
            return response()->json(['message' => 'This question does not belong to your department.'], 403);
        }

        $validated = $this->validatedQuestionData($request);

        $validatedReview = $request->validate([
            'review_status' => ['required', 'string', Rule::in(self::REVIEW_STATUSES)],
            'rejection_reason' => [
                Rule::requiredIf($request->review_status === 'rejected'),
                'nullable',
                'string',
                'max:1000'
            ],
        ]);

        $oldStatus = $question->review_status;
        $newStatus = $validatedReview['review_status'];
        $statusChanged = $oldStatus !== $newStatus;

        if ($statusChanged && in_array($newStatus, ['approved', 'rejected'])) {
            $question->reviewed_by = $request->user()->id;
            $question->reviewed_at = now();
        }

        // Counter logic for AI generated questions
        if ($statusChanged && $question->generation_job_id) {
            $job = $question->generationJob;
            if ($job) {
                // Decrement old status counter if it was approved/rejected
                if ($oldStatus === 'approved') {
                    $job->decrement('questions_approved');
                } elseif ($oldStatus === 'rejected') {
                    $job->decrement('questions_rejected');
                }

                // Increment new status counter
                if ($newStatus === 'approved') {
                    $job->increment('questions_approved');
                } elseif ($newStatus === 'rejected') {
                    $job->increment('questions_rejected');
                }
            }
        }

        if ($newStatus === 'approved') {
            $question->rejection_reason = null;
        } elseif ($newStatus === 'rejected') {
            $question->rejection_reason = $validatedReview['rejection_reason'];
        }

        // Edit Audit: Detect if any content-bearing field changed.
        $contentFields = [
            'question_text', 'marks', 'difficulty', 'bloom_taxonomy',
            'topic_tag', 'options', 'correct_answer'
        ];
        $isEdited = $question->is_edited;
        foreach ($contentFields as $field) {
            if (isset($validated[$field]) && $question->{$field} != $validated[$field]) {
                $isEdited = true;
                break;
            }
        }

        $question->update($validated + [
            'review_status' => $newStatus,
            'is_edited' => $isEdited
        ]);
        $question->load('exam:id,course_code');

        // If all questions in a job are reviewed, mark the job as completed.
        if ($question->generation_job_id) {
            $job = $question->generationJob->refresh();
            if ($job->status === 'REVIEW_PENDING' &&
                ($job->questions_approved + $job->questions_rejected) >= $job->questions_generated) {
                $job->update(['status' => 'COMPLETED', 'completed_at' => now()]);
            }
        }

        return response()->json([
            'question' => new QuestionBankResource($question),
        ]);
    }

    /**
     * DELETE /api/questions/{question}
     *
     * Refuses to delete a question that already has candidate answers —
     * answers cascade-delete at the database level, and silently wiping
     * a candidate's recorded response (and corrupting any already-graded
     * Result that references it) would be a much bigger surprise than a
     * blocked delete. Questions nobody has answered yet (the normal case
     * for review-workflow cleanup, e.g. rejecting an AI draft) delete
     * freely.
     */
    public function destroy(Request $request, Question $question)
    {
        $user = $request->user();

        // Examiner department authorization
        if ($user->role === 'examiner' && $question->exam->department_id !== $user->department_id) {
            return response()->json(['message' => 'This question does not belong to your department.'], 403);
        }

        if ($question->answers()->exists()) {
            return response()->json([
                'message' => 'This question cannot be deleted because a candidate has already answered it.',
            ], 422);
        }

        $question->delete();

        return response()->json(null, 204);
    }

    private function validatedQuestionData(Request $request): array
    {
        $user = $request->user();
        $validated = $request->validate([
            'exam_id' => ['required', 'integer', 'exists:exams,id'],
            'question_text' => ['required', 'string'],
            'question_type' => ['required', 'string', Rule::in(self::TYPES)],
            'marks' => ['required', 'integer', 'min:1', 'max:100'],
            'difficulty' => ['required', 'string', Rule::in(self::DIFFICULTIES)],
            'bloom_taxonomy' => ['required', 'string', Rule::in(self::BLOOM_LEVELS)],
            'topic_tag' => ['nullable', 'string', 'max:255'],
            // Deliberately just 'array' here, not per-item 'string' — mcq's
            // options are a flat string list, but matching's are pair
            // objects ({left, right}). Each type-specific branch below
            // validates its own shape explicitly instead.
            'options' => ['nullable', 'array'],
            'correct_answer' => ['nullable', 'string'],
            'test_cases' => ['nullable', 'array'],
            'test_cases.*.input' => ['nullable', 'string'],
            'test_cases.*.expected_output' => ['required', 'string'],
            'keywords' => ['nullable', 'array'],
            'keywords.*' => ['string', 'max:100'],
            'regex_patterns' => ['nullable', 'array'],
            'regex_patterns.*' => [
                'string',
                function ($attribute, $value, $fail) {
                    if (@preg_match($value, '') === false) {
                        $fail("The $attribute is not a valid regular expression.");
                    }
                }
            ],
            'is_ai_generated' => ['sometimes', 'boolean'],
        ]);

        // Examiner department authorization
        $exam = \App\Models\Exam::find($validated['exam_id']);
        if ($user->role === 'examiner' && $exam && $exam->department_id !== $user->department_id) {
            $this->failValidation('This exam does not belong to your department.');
        }

        if ($validated['question_type'] === 'mcq') {
            $options = $validated['options'] ?? [];
            $hasInvalidOption = !empty(array_filter(
                $options,
                fn ($option) => !is_string($option) || trim($option) === '',
            ));
            if (count($options) < 2 || $hasInvalidOption) {
                $this->failValidation('MCQ questions require at least two options.');
            }
            $normalized = array_map('mb_strtolower', array_map('trim', $options));
            if (count($normalized) !== count(array_unique($normalized))) {
                $this->failValidation('MCQ options must not contain duplicates.');
            }
            if (empty($validated['correct_answer']) || !in_array($validated['correct_answer'], $options, true)) {
                $this->failValidation('The correct answer must match one of the MCQ options.');
            }
            $validated['options'] = $options;
        } elseif ($validated['question_type'] === 'true_false') {
            $validated['options'] = null;
            if (!in_array($validated['correct_answer'] ?? null, ['True', 'False'], true)) {
                $this->failValidation('True/False questions require a correct_answer of exactly "True" or "False".');
            }
        } elseif ($validated['question_type'] === 'essay') {
            $validated['options'] = null;
            $validated['correct_answer'] = null;
        } elseif ($validated['question_type'] === 'short_answer') {
            $validated['options'] = null;
            if (empty($validated['correct_answer'])) {
                $this->failValidation('Short answer questions require a correct_answer.');
            }
        } elseif ($validated['question_type'] === 'matching') {
            $pairs = $validated['options'] ?? [];
            if (count($pairs) < 2) {
                $this->failValidation('Matching questions require at least two pairs.');
            }
            $normalizedPairs = [];
            $lefts = [];
            foreach ($pairs as $pair) {
                $left = is_array($pair) ? ($pair['left'] ?? null) : null;
                $right = is_array($pair) ? ($pair['right'] ?? null) : null;
                if (!is_string($left) || !is_string($right) || trim($left) === '' || trim($right) === '') {
                    $this->failValidation('Each matching pair needs both a left and right value.');
                }
                $left = trim($left);
                $right = trim($right);
                $lefts[] = mb_strtolower($left);
                $normalizedPairs[] = ['left' => $left, 'right' => $right];
            }
            if (count($lefts) !== count(array_unique($lefts))) {
                $this->failValidation('Matching pairs must not repeat the same left-side item.');
            }
            $validated['options'] = $normalizedPairs;
            // Grading (GradingService) reuses the existing exact-string-match
            // auto-grading path for 'matching' — this canonical JSON, keyed
            // by left item in the same order as $normalizedPairs, is what a
            // fully-correct candidate answer must byte-for-byte match.
            // JSON_UNESCAPED_UNICODE|SLASHES keeps this aligned with Dart's
            // jsonEncode default output on the candidate side.
            $validated['correct_answer'] = json_encode(
                array_combine(array_column($normalizedPairs, 'left'), array_column($normalizedPairs, 'right')),
                JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES,
            );
        } else { // code_snippet
            // Optional programming language, reusing the existing options
            // JSON column as a single-element list — no schema change.
            // No correct_answer: like essay, always pending_manual_review
            // (see GradingService) — no code execution sandbox exists.
            $language = $validated['options'][0] ?? null;
            $validated['options'] = is_string($language) && trim($language) !== ''
                ? [trim($language)]
                : null;
            $validated['correct_answer'] = null;
        }

        $validated['is_ai_generated'] = $validated['is_ai_generated'] ?? false;

        return $validated;
    }

    /**
     * Returns a clean JSON 422 without a stack trace, regardless of
     * APP_DEBUG — unlike abort(), which the default handler renders with
     * full exception/trace details when debug mode is on.
     */
    private function failValidation(string $message): never
    {
        throw new HttpResponseException(response()->json(['message' => $message], 422));
    }
}
