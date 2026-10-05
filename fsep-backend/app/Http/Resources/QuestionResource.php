<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Candidate-facing question representation.
 *
 * correct_answer stays on the Question model/database for the grading
 * system to use directly — it must never be serialized into this API
 * response, so it is deliberately left out of the field list below rather
 * than hidden after the fact.
 */
class QuestionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'exam_id' => $this->exam_id,
            'question_text' => $this->question_text,
            'question_type' => $this->question_type,
            'marks' => $this->marks,
            'difficulty' => $this->difficulty,
            'bloom_taxonomy' => $this->bloom_taxonomy,
            'topic_tag' => $this->topic_tag,
            'options' => $this->options,
            'is_ai_generated' => $this->is_ai_generated,
            'review_status' => $this->review_status,
        ];
    }
}
