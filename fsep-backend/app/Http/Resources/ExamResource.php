<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ExamResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'created_by' => $this->created_by,
            'department_id' => $this->department_id,
            'semester' => $this->semester,
            'title' => $this->title,
            'description' => $this->description,
            'course_code' => $this->course_code,
            'duration_minutes' => $this->duration_minutes,
            'total_marks' => $this->total_marks,
            'negative_marking_weight' => $this->negative_marking_weight,
            'pass_percentage' => $this->pass_percentage,
            'status' => $this->status,
            'allowed_platforms' => $this->allowed_platforms,
            'bcd_enabled' => $this->bcd_enabled,
            'randomize_questions' => $this->randomize_questions,
            'shuffle_choices' => $this->shuffle_choices,
            'is_offline_ready' => $this->is_offline_ready,
            'starts_at' => $this->starts_at,
            'ends_at' => $this->ends_at,
            'department' => new DepartmentResource($this->whenLoaded('department')),
            'question_configurations' => ExamQuestionConfigurationResource::collection($this->whenLoaded('questionConfigurations')),
            'questions' => QuestionResource::collection($this->whenLoaded('questions')),
        ];
    }
}
