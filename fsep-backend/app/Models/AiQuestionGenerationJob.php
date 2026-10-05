<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class AiQuestionGenerationJob extends Model
{
    protected $fillable = [
        'examiner_id',
        'document_name',
        'chunks',
        'params',
        'exam_ids',
        'status',
        'last_error',
        'questions_generated',
        'questions_approved',
        'questions_rejected',
        'parsing_at',
        'generating_at',
        'review_pending_at',
        'completed_at',
        'failed_at',
    ];

    protected $casts = [
        'chunks' => 'array',
        'params' => 'array',
        'exam_ids' => 'array',
        'parsing_at' => 'datetime',
        'generating_at' => 'datetime',
        'review_pending_at' => 'datetime',
        'completed_at' => 'datetime',
        'failed_at' => 'datetime',
        'questions_generated' => 'integer',
        'questions_approved' => 'integer',
        'questions_rejected' => 'integer',
    ];

    public function examiner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'examiner_id');
    }

    public function questions(): HasMany
    {
        return $this->hasMany(Question::class, 'generation_job_id');
    }
}
