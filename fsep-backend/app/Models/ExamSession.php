<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class ExamSession extends Model
{
    use HasFactory;

    protected $fillable = [
        'exam_id',
        'candidate_id',
        'status',
        'started_at',
        'expires_at',
        'submitted_at',
    ];

    protected $casts = [
        'started_at' => 'datetime',
        'expires_at' => 'datetime',
        'submitted_at' => 'datetime',
    ];

    /**
     * Server-authoritative: true once the current time has passed this
     * session's expires_at. Callers must use this rather than trusting
     * anything client-supplied.
     */
    public function isExpired(): bool
    {
        return $this->expires_at !== null && now()->greaterThanOrEqualTo($this->expires_at);
    }

    public function exam(): BelongsTo
    {
        return $this->belongsTo(Exam::class);
    }

    public function candidate(): BelongsTo
    {
        return $this->belongsTo(User::class, 'candidate_id');
    }

    public function answers(): HasMany
    {
        return $this->hasMany(Answer::class);
    }

    public function behaviorEvents(): HasMany
    {
        return $this->hasMany(BehaviorEvent::class);
    }

    public function result(): HasOne
    {
        return $this->hasOne(Result::class);
    }

    public function learningGapReport(): HasOne
    {
        return $this->hasOne(LearningGapReport::class);
    }
}
