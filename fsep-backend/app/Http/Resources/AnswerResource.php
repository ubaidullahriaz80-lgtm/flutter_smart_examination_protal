<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A candidate's saved answer. Deliberately excludes is_correct and
 * obtained_marks — grading is a separate, later concern and must never be
 * revealed to the candidate during answer selection.
 */
class AnswerResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'question_id' => $this->question_id,
            'selected_option' => $this->selected_option,
        ];
    }
}
