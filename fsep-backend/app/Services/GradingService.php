<?php

namespace App\Services;

use App\Models\Answer;
use App\Models\ExamSession;
use App\Models\Result;
use Illuminate\Support\Facades\Log;

/**
 * Service for automatically grading submitted exam sessions.
 */
class GradingService
{
    private const AUTO_GRADABLE_TYPES = ['mcq', 'true_false', 'short_answer', 'matching', 'code_snippet'];

    protected $codeExecution;

    public function __construct(CodeExecutionService $codeExecution)
    {
        $this->codeExecution = $codeExecution;
    }

    public function gradeSession(ExamSession $session): Result
    {
        $session->loadMissing([
            'exam.questions' => fn ($query) => $query->where('review_status', 'approved'),
            'answers',
        ]);

        $negativeMarkingWeight = (float) $session->exam->negative_marking_weight;
        $answersByQuestionId = $session->answers->keyBy('question_id');

        $totalScore = 0.0;
        $maxScore = 0.0;
        $hasPendingReview = false;

        foreach ($session->exam->questions as $question) {
            $maxScore += $question->marks;

            /** @var Answer|null $answer */
            $answer = $answersByQuestionId->get($question->id);

            if ($answer === null) {
                continue;
            }

            if (!in_array($question->question_type, self::AUTO_GRADABLE_TYPES, true)) {
                $answer->grading_status = 'pending_manual_review';
                $answer->is_correct = null;
                $answer->obtained_marks = null;
                $answer->save();
                $hasPendingReview = true;
                continue;
            }

            if ($question->question_type === 'code_snippet') {
                $codeResult = $this->gradeCodeSnippet($answer, $question);
                $isCorrect = $codeResult['is_correct'];
                $answer->grading_metadata = [
                    'scoring_vector' => $codeResult['results'],
                    'passed_count' => collect($codeResult['results'])->where('passed', true)->count(),
                    'total_count' => count($codeResult['results']),
                ];

                if ($answer->grading_status === 'pending_manual_review') {
                    $hasPendingReview = true;
                    $totalScore += 0;
                    continue;
                }
            } elseif ($question->question_type === 'short_answer') {
                $gradeResult = $this->gradeShortAnswer($answer, $question);
                $isCorrect = $gradeResult['is_correct'];
                if ($gradeResult['status'] === 'pending_manual_review') {
                    $answer->grading_status = 'pending_manual_review';
                    $answer->is_correct = null;
                    $answer->obtained_marks = null;
                    $answer->save();
                    $hasPendingReview = true;
                    $totalScore += 0;
                    continue;
                }
            } else {
                $isCorrect = $question->correct_answer !== null
                    && trim((string) $answer->selected_option) === trim((string) $question->correct_answer);
            }

            $obtainedMarks = $isCorrect
                ? (float) $question->marks
                : -($question->marks * $negativeMarkingWeight);

            $answer->grading_status = 'graded';
            $answer->is_correct = $isCorrect;
            $answer->obtained_marks = $obtainedMarks;
            $answer->save();

            $totalScore += $obtainedMarks;
        }

        return Result::updateOrCreate(
            ['exam_session_id' => $session->id],
            [
                'total_score' => round($totalScore, 2),
                'max_score' => round($maxScore, 2),
                'status' => $hasPendingReview ? 'pending_manual_review' : 'graded',
                'graded_at' => now(),
            ],
        );
    }

    private function gradeShortAnswer(Answer $answer, \App\Models\Question $question): array
    {
        $candidateAnswer = trim((string) $answer->selected_option);
        $correctAnswer = trim((string) ($question->correct_answer ?? ''));

        if ($correctAnswer !== '' && mb_strtolower($candidateAnswer) === mb_strtolower($correctAnswer)) {
            return ['is_correct' => true, 'status' => 'graded'];
        }

        $patterns = $question->regex_patterns ?? [];
        foreach ($patterns as $pattern) {
            try {
                if (@preg_match($pattern, $candidateAnswer)) {
                    return ['is_correct' => true, 'status' => 'graded'];
                }
            } catch (\Throwable $e) {
                Log::warning("Invalid regex pattern in question {$question->id}: $pattern");
            }
        }

        $keywords = $question->keywords ?? [];
        if (!empty($keywords)) {
            $matchedCount = 0;
            $lowerCandidate = mb_strtolower($candidateAnswer);
            foreach ($keywords as $keyword) {
                if (str_contains($lowerCandidate, mb_strtolower(trim($keyword)))) {
                    $matchedCount++;
                }
            }
            if ($matchedCount > 0) {
                return ['is_correct' => true, 'status' => 'graded'];
            }
        }

        return ['is_correct' => false, 'status' => 'pending_manual_review'];
    }

    private function gradeCodeSnippet(Answer $answer, \App\Models\Question $question): array
    {
        $code = $answer->selected_option;
        $language = $question->options[0] ?? 'python';
        $testCases = $question->test_cases ?? [];

        if (empty($testCases)) {
            $answer->grading_status = 'pending_manual_review';
            $answer->save();
            return ['is_correct' => false, 'results' => []];
        }

        try {
            $results = $this->codeExecution->execute($code, $language, $testCases);
            $allPassed = !empty($results) && collect($results)->every('passed', true);

            Log::info("Code execution results", ['results' => $results, 'allPassed' => $allPassed]);

            return ['is_correct' => $allPassed, 'results' => $results];

        } catch (\Exception $e) {
            Log::error("Code grading failed: " . $e->getMessage());
            $answer->grading_status = 'pending_manual_review';
            $answer->save();
            return ['is_correct' => false, 'results' => []];
        }
    }

    public function recalculateResult(ExamSession $session): Result
    {
        $session->loadMissing([
            'exam.questions' => fn ($query) => $query->where('review_status', 'approved'),
            'answers',
        ]);

        $maxScore = 0.0;
        foreach ($session->exam->questions as $question) {
            $maxScore += $question->marks;
        }

        $totalScore = 0.0;
        $hasPendingReview = false;

        foreach ($session->answers as $answer) {
            if ($answer->grading_status === 'pending_manual_review') {
                $hasPendingReview = true;
                continue;
            }

            if ($answer->grading_status === 'graded' && $answer->obtained_marks !== null) {
                $totalScore += $answer->obtained_marks;
            }
        }

        return Result::updateOrCreate(
            ['exam_session_id' => $session->id],
            [
                'total_score' => round($totalScore, 2),
                'max_score' => round($maxScore, 2),
                'status' => $hasPendingReview ? 'pending_manual_review' : 'graded',
                'graded_at' => now(),
            ],
        );
    }
}
