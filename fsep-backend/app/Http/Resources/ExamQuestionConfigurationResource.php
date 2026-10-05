<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ExamQuestionConfigurationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'exam_id' => $this->exam_id,
            'question_type' => $this->question_type,
            'question_count' => $this->question_count,
            'bloom_taxonomy' => $this->bloom_taxonomy,
            'marks' => $this->marks,
        ];
    }
}
