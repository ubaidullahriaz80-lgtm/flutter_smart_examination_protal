<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Full question representation for the examiner-facing Question Bank —
 * distinct from the candidate-safe QuestionResource (which deliberately
 * omits correct_answer/created_by). This resource is only ever returned
 * from routes restricted to role:examiner; it must never be reachable by
 * candidates.
 */
class QuestionBankResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'exam_id' => $this->exam_id,
            'course_code' => $this->whenLoaded('exam', fn () => $this->exam->course_code),
            'created_by' => $this->created_by,
            'question_text' => $this->question_text,
            'question_type' => $this->question_type,
            'marks' => $this->marks,
            'difficulty' => $this->difficulty,
            'bloom_taxonomy' => $this->bloom_taxonomy,
            'topic_tag' => $this->topic_tag,
            'options' => $this->options,
            'correct_answer' => $this->correct_answer,
            'test_cases' => $this->test_cases,
            'keywords' => $this->keywords,
            'regex_patterns' => $this->regex_patterns,
            'is_ai_generated' => $this->is_ai_generated,
            'is_edited' => $this->is_edited,
            'generation_job_id' => $this->generation_job_id,
            'review_status' => $this->review_status,
            'reviewed_by' => $this->reviewed_by,
            'reviewed_at' => $this->reviewed_at,
            'rejection_reason' => $this->rejection_reason,
        ];
    }
}
