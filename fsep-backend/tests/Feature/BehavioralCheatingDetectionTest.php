<?php

namespace Tests\Feature;

use App\Models\Exam;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesTestUsers;
use Tests\TestCase;

/**
 * Novelty #1 — Behavioral Cheating Detection (SRS FR-KS-03 §3.5/§4.1).
 * Verifies the real scoring thresholds as per SRS §4.1.4.
 */
class BehavioralCheatingDetectionTest extends TestCase
{
    use RefreshDatabase;
    use CreatesTestUsers;

    private function startExamSession(): array
    {
        [$examiner] = $this->makeUserWithToken('examiner');
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'BCD Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
            'status' => 'draft',
            'bcd_enabled' => true,
        ]);
        [, $candidateToken] = $this->makeUserWithToken('candidate');
        $headers = $this->authHeaders($candidateToken);

        $sessionId = $this->postJson("/api/exams/{$exam->id}/session", [], $headers)
            ->json('session.id');

        return [$sessionId, $headers];
    }

    public function test_recording_events_accumulates_suspicion_score_and_crosses_thresholds(): void
    {
        [$sessionId, $headers] = $this->startExamSession();

        // 1. focus_lost (WindowFocusLoss alias) = 18 pts
        $r1 = $this->postJson(
            "/api/exam-sessions/{$sessionId}/behavior-events",
            ['event_type' => 'focus_lost'],
            $headers,
        );
        $r1->assertStatus(201)->assertJson(['suspicion_score' => 18, 'suspicion_status' => 'low']);

        // 2. 2nd focus_lost: 18 * log2(2+1) = 28.5 -> 29. Still low.
        $this->postJson(
            "/api/exam-sessions/{$sessionId}/behavior-events",
            ['event_type' => 'focus_lost'],
            $headers,
        )->assertJson(['suspicion_score' => 29, 'suspicion_status' => 'low']);

        // 3. navigation_away = 25 pts. 29 + 25 = 54 -> medium.
        $r3 = $this->postJson(
            "/api/exam-sessions/{$sessionId}/behavior-events",
            ['event_type' => 'navigation_away'],
            $headers,
        );
        $r3->assertJson(['suspicion_score' => 54, 'suspicion_status' => 'medium']);

        // 4. TabSwitchAttempt = 20. 54 + 20 = 74 -> high.
        $this->postJson(
            "/api/exam-sessions/{$sessionId}/behavior-events",
            ['event_type' => 'TabSwitchAttempt'],
            $headers,
        )->assertJson(['suspicion_score' => 74, 'suspicion_status' => 'high']);
    }

    public function test_a_candidate_cannot_view_another_candidates_behavior_events(): void
    {
        [$sessionId] = $this->startExamSession();
        [, $otherToken] = $this->makeUserWithToken('candidate', 'someoneelse@test.local');

        $this->getJson(
            "/api/exam-sessions/{$sessionId}/behavior-events",
            $this->authHeaders($otherToken),
        )->assertStatus(403);
    }

    public function test_live_invigilator_can_view_any_sessions_behavior_events(): void
    {
        [$sessionId, $candidateHeaders] = $this->startExamSession();
        $this->postJson(
            "/api/exam-sessions/{$sessionId}/behavior-events",
            ['event_type' => 'focus_lost'],
            $candidateHeaders,
        );

        [, $invigilatorToken] = $this->makeUserWithToken('live_invigilator');

        $this->getJson(
            "/api/exam-sessions/{$sessionId}/behavior-events",
            $this->authHeaders($invigilatorToken),
        )->assertStatus(200)->assertJson(['suspicion_score' => 18]);
    }
}
