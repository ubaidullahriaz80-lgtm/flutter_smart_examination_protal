<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Question extends Model
{
    use HasFactory;

    protected $fillable = [
        'exam_id',
        'created_by',
        'question_text',
        'question_type',
        'marks',
        'difficulty',
        'bloom_taxonomy',
        'topic_tag',
        'options',
        'correct_answer',
        'test_cases',
        'keywords',
        'regex_patterns',
        'is_ai_generated',
        'is_edited',
        'generation_job_id',
        'review_status',
        'reviewed_by',
        'reviewed_at',
        'rejection_reason',
    ];

    protected $casts = [
        'options' => 'array',
        'test_cases' => 'array',
        'keywords' => 'array',
        'regex_patterns' => 'array',
        'marks' => 'integer',
        'is_ai_generated' => 'boolean',
        'is_edited' => 'boolean',
        'reviewed_at' => 'datetime',
    ];

    public function exam(): BelongsTo
    {
        return $this->belongsTo(Exam::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function generationJob(): BelongsTo
    {
        return $this->belongsTo(AiQuestionGenerationJob::class, 'generation_job_id');
    }

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    public function answers(): HasMany
    {
        return $this->hasMany(Answer::class);
    }
}
