<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ExamSessionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'exam_id' => $this->exam_id,
            'status' => $this->status,
            'started_at' => $this->started_at,
            'expires_at' => $this->expires_at,
            'submitted_at' => $this->submitted_at,
            // Lets the client compute remaining time against the server's
            // clock instead of its own, avoiding drift from client clock
            // skew — the timer must derive from (expires_at - server_time)
            // at the moment this response was generated, not from the
            // device's own "now".
            'server_time' => now(),
            'answers' => AnswerResource::collection($this->whenLoaded('answers')),
        ];
    }
}
