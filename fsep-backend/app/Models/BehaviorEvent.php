<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Model representing a recorded behavioral signal during an active exam session.
 */
class BehaviorEvent extends Model
{
    use HasFactory;

    protected $fillable = [
        'exam_session_id',
        'client_uuid',
        'candidate_id',
        'event_type',
        'severity',
        'event_timestamp',
        'suspicion_points',
        'metadata',
    ];

    protected $casts = [
        'suspicion_points' => 'integer',
        'metadata' => 'array',
        'event_timestamp' => 'datetime',
    ];

    public function examSession(): BelongsTo
    {
        return $this->belongsTo(ExamSession::class);
    }

    public function candidate(): BelongsTo
    {
        return $this->belongsTo(User::class, 'candidate_id');
    }

    public function reviewAction(): \Illuminate\Database\Eloquent\Relations\HasOne
    {
        return $this->hasOne(BehavioralReviewAction::class, 'event_id');
    }
}
