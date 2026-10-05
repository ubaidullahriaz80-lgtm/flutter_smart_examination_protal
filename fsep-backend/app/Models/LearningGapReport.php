<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LearningGapReport extends Model
{
    protected $fillable = [
        'exam_session_id',
        'candidate_id',
        'exam_id',
        'learning_gaps',
        'all_topics',
        'bloom_profile',
        'difficulty_profile',
        'improvement_roadmap',
        'topics_analyzed',
        'questions_attempted',
        'generated_at',
    ];

    protected $casts = [
        'learning_gaps' => 'array',
        'all_topics' => 'array',
        'bloom_profile' => 'array',
        'difficulty_profile' => 'array',
        'improvement_roadmap' => 'array',
        'generated_at' => 'datetime',
    ];

    public function session(): BelongsTo
    {
        return $this->belongsTo(ExamSession::class, 'exam_session_id');
    }

    public function candidate(): BelongsTo
    {
        return $this->belongsTo(User::class, 'candidate_id');
    }

    public function exam(): BelongsTo
    {
        return $this->belongsTo(Exam::class, 'exam_id');
    }
}
