<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class BehavioralRiskScore extends Model
{
    protected $fillable = [
        'exam_session_id',
        'risk_score',
        'risk_band',
        'computed_at',
        'event_breakdown',
    ];

    protected $casts = [
        'risk_score' => 'integer',
        'computed_at' => 'datetime',
        'event_breakdown' => 'array',
    ];

    public function session(): BelongsTo
    {
        return $this->belongsTo(ExamSession::class, 'exam_session_id');
    }
}
