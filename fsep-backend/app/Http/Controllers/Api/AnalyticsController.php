<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Exam;
use App\Models\ExamSession;
use App\Models\Result;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;

/**
 * Controller for cohort and administrative assessment analytics.
 */
class AnalyticsController extends Controller
{
    private const DISTRIBUTION_BUCKETS = [
        ['label' => '0-49%', 'min' => 0, 'max' => 49],
        ['label' => '50-59%', 'min' => 50, 'max' => 59],
        ['label' => '60-69%', 'min' => 60, 'max' => 69],
        ['label' => '70-79%', 'min' => 70, 'max' => 79],
        ['label' => '80-89%', 'min' => 80, 'max' => 89],
        ['label' => '90-100%', 'min' => 90, 'max' => 100],
    ];

    public function cohort(Request $request)
    {
        $examId = $request->integer('exam_id') ?: null;

        if ($examId !== null && !Exam::whereKey($examId)->exists()) {
            return response()->json(['message' => 'Exam not found.'], 404);
        }

        $sessionsQuery = ExamSession::query()
            ->where('status', 'submitted')
            ->whereHas('result')
            ->with('result');

        if ($examId !== null) {
            $sessionsQuery->where('exam_id', $examId);
        }

        $sessions = $sessionsQuery->get();

        return response()->json([
            'summary' => $this->summarize($sessions, $examId),
            'exam_statistics' => $this->perExamStatistics(),
            'score_distribution' => $this->scoreDistribution($sessions),
            'behavioral_risk_distribution' => $this->riskDistribution($sessions),
            'device_reliability' => $this->deviceReliability($sessions),
        ]);
    }

    private function deviceReliability(Collection $sessions): array
    {
        if ($sessions->isEmpty()) {
            return ['reliable_sessions_count' => 0, 'reliability_rate' => 0];
        }

        $sessionIds = $sessions->pluck('id');
        $unreliableSessionIds = \App\Models\BehaviorEvent::whereIn('exam_session_id', $sessionIds)
            ->where('event_type', 'DeviceChange')
            ->pluck('exam_session_id')
            ->unique();

        $reliableCount = $sessions->count() - $unreliableSessionIds->count();

        return [
            'reliable_sessions_count' => $reliableCount,
            'total_sessions' => $sessions->count(),
            'reliability_rate' => round(($reliableCount / $sessions->count()) * 100, 1),
        ];
    }

    private function riskDistribution(Collection $sessions): array
    {
        $examIds = $sessions->pluck('exam_id')->unique();

        $riskScores = \App\Models\BehavioralRiskScore::whereIn('exam_session_id', $sessions->pluck('id'))->pluck('risk_score');

        return [
            ['range' => 'Low (0-30)', 'count' => $riskScores->filter(fn($s) => $s <= 30)->count()],
            ['range' => 'Medium (31-60)', 'count' => $riskScores->filter(fn($s) => $s > 30 && $s <= 60)->count()],
            ['range' => 'High (61-80)', 'count' => $riskScores->filter(fn($s) => $s > 60 && $s <= 80)->count()],
            ['range' => 'Critical (81-100)', 'count' => $riskScores->filter(fn($s) => $s > 80)->count()],
        ];
    }

    private function summarize(Collection $sessions, ?int $examId): array
    {
        $results = $sessions->pluck('result');
        $percentages = $results->map(fn (Result $r) => $this->percentage($r));

        $completionTimes = $sessions->map(fn($s) => $s->submitted_at->diffInMinutes($s->started_at, true));

        $totalCandidatesCount = \App\Models\User::where('role', 'candidate')->count();
        $uniqueCandidatesSubmitted = $sessions->pluck('candidate_id')->unique()->count();
        $completionRate = $totalCandidatesCount > 0
            ? round(($uniqueCandidatesSubmitted / $totalCandidatesCount) * 100, 1)
            : 0;

        return [
            'exam_id' => $examId,
            'exam_title' => $examId !== null ? Exam::find($examId)?->title : null,
            'candidate_count' => $uniqueCandidatesSubmitted,
            'total_eligible_candidates' => $totalCandidatesCount,
            'completion_rate' => $completionRate,
            'submission_count' => $sessions->count(),
            'pending_manual_review_count' => $results
                ->where('status', 'pending_manual_review')
                ->count(),
            'average_score' => $results->isEmpty() ? null : round($results->avg('total_score'), 2),
            'average_percentage' => $percentages->isEmpty() ? null : round($percentages->avg(), 1),
            'highest_percentage' => $percentages->isEmpty() ? null : round($percentages->max(), 1),
            'lowest_percentage' => $percentages->isEmpty() ? null : round($percentages->min(), 1),
            'median_completion_time' => $completionTimes->isEmpty() ? null : round($completionTimes->median(), 1),
        ];
    }

    private function perExamStatistics(): array
    {
        return Exam::all()->map(function (Exam $exam) {
            $sessions = $exam->sessions()
                ->where('status', 'submitted')
                ->whereHas('result')
                ->with('result')
                ->get();
            $results = $sessions->pluck('result');
            $percentages = $results->map(fn (Result $r) => $this->percentage($r));

            return [
                'exam_id' => $exam->id,
                'exam_title' => $exam->title,
                'course_code' => $exam->course_code,
                'submission_count' => $sessions->count(),
                'average_marks' => $results->isEmpty() ? null : round($results->avg('total_score'), 2),
                'average_percentage' => $percentages->isEmpty() ? null : round($percentages->avg(), 1),
                'highest_score' => $results->isEmpty() ? null : round($results->max('total_score'), 2),
                'lowest_score' => $results->isEmpty() ? null : round($results->min('total_score'), 2),
            ];
        })->values()->all();
    }

    private function scoreDistribution(Collection $sessions): array
    {
        $percentages = $sessions->pluck('result')->map(fn (Result $r) => $this->percentage($r));

        return collect(self::DISTRIBUTION_BUCKETS)->map(function (array $bucket) use ($percentages) {
            $count = $percentages
                ->filter(fn (float $p) => $p >= $bucket['min'] && $p <= $bucket['max'])
                ->count();

            return ['range' => $bucket['label'], 'count' => $count];
        })->values()->all();
    }

    private function percentage(Result $result): float
    {
        return $result->max_score > 0
            ? round(($result->total_score / $result->max_score) * 100, 1)
            : 0.0;
    }
}
