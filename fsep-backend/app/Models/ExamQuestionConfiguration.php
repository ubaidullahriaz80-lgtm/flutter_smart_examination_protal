<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ExamQuestionConfiguration extends Model
{
    use HasFactory;

    protected $fillable = [
        'exam_id',
        'question_type',
        'question_count',
        'bloom_taxonomy',
        'marks',
    ];

    protected $casts = [
        'exam_id' => 'integer',
        'question_count' => 'integer',
        'marks' => 'float',
    ];

    public function exam(): BelongsTo
    {
        return $this->belongsTo(Exam::class);
    }
}
