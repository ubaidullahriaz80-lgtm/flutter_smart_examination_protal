<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Exam extends Model
{
    use HasFactory;

    protected $fillable = [
        'created_by',
        'department_id',
        'semester',
        'title',
        'description',
        'course_code',
        'duration_minutes',
        'total_marks',
        'negative_marking_weight',
        'pass_percentage',
        'status',
        'allowed_platforms',
        'bcd_enabled',
        'randomize_questions',
        'shuffle_choices',
        'is_offline_ready',
        'starts_at',
        'ends_at',
    ];

    protected $casts = [
        'department_id' => 'integer',
        'semester' => 'integer',
        'allowed_platforms' => 'array',
        'bcd_enabled' => 'boolean',
        'randomize_questions' => 'boolean',
        'shuffle_choices' => 'boolean',
        'is_offline_ready' => 'boolean',
        'pass_percentage' => 'float',
        'starts_at' => 'datetime',
        'ends_at' => 'datetime',
    ];

    protected $attributes = [
        'is_offline_ready' => false,
        'randomize_questions' => false,
        'shuffle_choices' => false,
        'bcd_enabled' => true,
    ];

    public function department(): BelongsTo
    {
        return $this->belongsTo(Department::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function questions(): HasMany
    {
        return $this->hasMany(Question::class);
    }

    public function questionConfigurations(): HasMany
    {
        return $this->hasMany(ExamQuestionConfiguration::class);
    }

    public function sessions(): HasMany
    {
        return $this->hasMany(ExamSession::class);
    }
}
