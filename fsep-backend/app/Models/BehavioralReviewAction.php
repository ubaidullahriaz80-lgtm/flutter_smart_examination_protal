<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class BehavioralReviewAction extends Model
{
    protected $fillable = [
        'event_id',
        'invigilator_id',
        'action',
        'note',
        'actioned_at',
    ];

    protected $casts = [
        'actioned_at' => 'datetime',
    ];

    public function event(): BelongsTo
    {
        return $this->belongsTo(BehaviorEvent::class, 'event_id');
    }

    public function invigilator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'invigilator_id');
    }
}
