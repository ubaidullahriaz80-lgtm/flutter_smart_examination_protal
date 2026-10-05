<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Result extends Model
{
    protected $fillable = [
        'exam_session_id',
        'total_score',
        'max_score',
        'status',
        'graded_at',
    ];

    protected $casts = [
        'total_score' => 'float',
        'max_score' => 'float',
        'graded_at' => 'datetime',
    ];

    public function examSession(): BelongsTo
    {
        return $this->belongsTo(ExamSession::class);
    }
}
