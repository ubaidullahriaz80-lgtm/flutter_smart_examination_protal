<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Answer extends Model
{
    protected $fillable = [
        'exam_session_id',
        'question_id',
        'selected_option',
        'grading_status',
        'is_correct',
        'obtained_marks',
        'grading_metadata',
    ];

    protected $casts = [
        'is_correct' => 'boolean',
        'obtained_marks' => 'float',
        'grading_metadata' => 'array',
    ];

    public function examSession(): BelongsTo
    {
        return $this->belongsTo(ExamSession::class);
    }

    public function question(): BelongsTo
    {
        return $this->belongsTo(Question::class);
    }
}
