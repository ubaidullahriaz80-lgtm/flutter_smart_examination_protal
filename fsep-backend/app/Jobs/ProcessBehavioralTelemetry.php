<?php

namespace App\Jobs;

use App\Models\ExamSession;
use App\Services\BehavioralService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

/**
 * Asynchronous job to recalculate behavioral risk scores.
 */
class ProcessBehavioralTelemetry implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected $sessionId;

    public function __construct(int $sessionId)
    {
        $this->sessionId = $sessionId;
    }

    public function handle(BehavioralService $service): void
    {
        $session = ExamSession::find($this->sessionId);
        if ($session) {
            $service->computeRiskScore($session);
        }
    }
}
