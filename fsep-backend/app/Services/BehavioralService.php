<?php

namespace App\Services;

use App\Models\BehavioralAlert;
use App\Models\BehavioralRiskScore;
use App\Models\ExamSession;
use App\Models\User;

class BehavioralService
{
    protected $fcm;

    public function __construct(FcmService $fcm)
    {
        $this->fcm = $fcm;
    }

    private const EVENT_POINTS = [
        'RapidAnswerChange' => 15,
        'ExcessiveQuestionSwitch' => 12,
        'UnusualAnsweringSpeed' => 10,
        'TabSwitchAttempt' => 20,
        'WindowFocusLoss' => 18,
        'IdlePeriod' => 8,
        'DeviceChange' => 25,
        'focus_lost' => 18,
        'navigation_away' => 25,
        'focus_regained' => 0,
    ];

    /**
     * Computes the cumulative risk score for an exam session.
     */
    public function computeRiskScore(ExamSession $session): array
    {
        $oldRisk = BehavioralRiskScore::where('exam_session_id', $session->id)->first();
        $oldScore = $oldRisk ? $oldRisk->risk_score : 0;

        $events = $session->behaviorEvents()->get()->groupBy('event_type');
        $totalScore = 0.0;
        $breakdown = [];

        foreach (self::EVENT_POINTS as $type => $weight) {
            $count = isset($events[$type]) ? $events[$type]->count() : 0;
            if ($count === 0) continue;

            $contribution = $weight * log($count + 1, 2);
            $totalScore += $contribution;
            $breakdown[$type] = [
                'count' => $count,
                'weight' => $weight,
                'contribution' => round($contribution, 2)
            ];
        }

        $finalScore = min(100, (int) round($totalScore));

        $status = match (true) {
            $finalScore >= 81 => 'critical',
            $finalScore >= 61 => 'high',
            $finalScore >= 31 => 'medium',
            default => 'low',
        };

        BehavioralRiskScore::updateOrCreate(
            ['exam_session_id' => $session->id],
            [
                'risk_score' => $finalScore,
                'risk_band' => $status,
                'computed_at' => now(),
                'event_breakdown' => $breakdown,
            ]
        );

        if ($oldScore <= 60 && $finalScore > 60) {
            $this->generateStaffAlert($session, $finalScore, $status);
        }

        return [
            'suspicion_score' => $finalScore,
            'suspicion_status' => $status,
            'event_breakdown' => $breakdown,
        ];
    }

    private function generateStaffAlert(ExamSession $session, int $score, string $band): void
    {
        BehavioralAlert::create([
            'exam_session_id' => $session->id,
            'candidate_id' => $session->candidate_id,
            'risk_score' => $score,
            'risk_band' => $band,
            'triggered_at' => now(),
        ]);

        $candidateName = $session->candidate->name;
        $examTitle = $session->exam->title;
        $bandLabel = ucfirst($band);

        $title = "Security Alert: $bandLabel Risk";
        $body = "Candidate $candidateName reached $bandLabel risk ($score pts) in '$examTitle'.";

        $data = [
            'type' => 'bcd_alert',
            'session_id' => (string) $session->id,
            'exam_id' => (string) $session->exam_id,
        ];

        $this->fcm->sendToUser($session->exam->creator, $title, $body, $data);

        $invigilators = User::where('role', 'live_invigilator')->get();
        $this->fcm->sendToUsers($invigilators, $title, $body, $data);
    }

    public function deriveSeverity(string $eventType): string
    {
        $points = self::EVENT_POINTS[$eventType] ?? 0;

        return match (true) {
            $points >= 25 => 'CRITICAL',
            $points >= 18 => 'HIGH',
            $points >= 11 => 'MEDIUM',
            default => 'LOW',
        };
    }

    public function getEventPoints(): array
    {
        return self::EVENT_POINTS;
    }
}
