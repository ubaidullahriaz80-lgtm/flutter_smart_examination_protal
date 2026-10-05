<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Resource for candidate-safe exam result responses.
 */
class ResultResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $percentage = $this->max_score > 0
            ? round(($this->total_score / $this->max_score) * 100, 1)
            : 0;

        $examId = $this->examSession->exam_id;
        $cohortScores = \App\Models\Result::whereHas('examSession', function($query) use ($examId) {
            $query->where('exam_id', $examId);
        })->where('status', 'graded')->pluck('total_score');

        $totalCount = $cohortScores->count();
        if ($totalCount > 0) {
            $atOrBelowCount = $cohortScores->filter(fn($score) => $score <= $this->total_score)->count();
            $percentile = round(($atOrBelowCount / $totalCount) * 100, 1);
        } else {
            $percentile = 100.0;
        }

        $passPercentage = (float) $this->examSession->exam->pass_percentage;
        $passFail = ($percentage >= $passPercentage) ? 'pass' : 'fail';

        return [
            'session_id' => $this->exam_session_id,
            'total_score' => $this->total_score,
            'max_score' => $this->max_score,
            'percentage' => $percentage,
            'percentile' => $percentile,
            'pass_fail' => $passFail,
            'status' => $this->status,
            'graded_at' => $this->graded_at,
            'question_results' => $this->examSession->answers->map(fn ($answer) => [
                'question_id' => $answer->question_id,
                'is_correct' => $answer->is_correct,
                'obtained_marks' => $answer->obtained_marks,
            ])->values(),
        ];
    }
}
