<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class BehavioralAlert extends Model
{
    protected $fillable = [
        'exam_session_id',
        'candidate_id',
        'risk_score',
        'risk_band',
        'triggered_at',
    ];

    protected $casts = [
        'risk_score' => 'integer',
        'triggered_at' => 'datetime',
    ];

    public function session(): BelongsTo
    {
        return $this->belongsTo(ExamSession::class, 'exam_session_id');
    }

    public function candidate(): BelongsTo
    {
        return $this->belongsTo(User::class, 'candidate_id');
    }
}
