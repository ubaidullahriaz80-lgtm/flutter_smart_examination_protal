<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\ExamSession;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RiskScoringTest extends TestCase
{
    use RefreshDatabase;

    public function test_single_critical_event_is_low_risk(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $candidate = User::factory()->create(['role' => 'candidate']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'T',
            'duration_minutes' => 60,
            'bcd_enabled' => true,
        ]);
        $session = ExamSession::create([
            'exam_id' => $exam->id,
            'candidate_id' => $candidate->id,
            'status' => 'in_progress',
            'expires_at' => now()->addHour(),
        ]);

        // DeviceChange = 25 pts
        $response = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", [
            'event_type' => 'DeviceChange'
        ]);

        $response->assertStatus(201);
        $this->assertEquals(25, $response->json('suspicion_score'));
        $this->assertEquals('low', $response->json('suspicion_status'));

        $this->assertDatabaseHas('behavioral_risk_scores', [
            'exam_session_id' => $session->id,
            'risk_score' => 25,
            'risk_band' => 'low'
        ]);
    }

    public function test_multiple_events_cross_thresholds(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $candidate = User::factory()->create(['role' => 'candidate']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'T',
            'duration_minutes' => 60,
            'bcd_enabled' => true,
        ]);
        $session = ExamSession::create([
            'exam_id' => $exam->id,
            'candidate_id' => $candidate->id,
            'status' => 'in_progress',
            'expires_at' => now()->addHour(),
        ]);

        // 1. DeviceChange (25) -> Low
        $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", ['event_type' => 'DeviceChange']);

        // 2. TabSwitchAttempt (20) -> 25 + 20 = 45 -> Medium (31-60)
        $response = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", ['event_type' => 'TabSwitchAttempt']);
        $this->assertEquals(45, $response->json('suspicion_score'));
        $this->assertEquals('medium', $response->json('suspicion_status'));

        // 3. WindowFocusLoss (18) -> 45 + 18 = 63 -> High (61-80)
        $response = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", ['event_type' => 'WindowFocusLoss']);
        $this->assertEquals(63, $response->json('suspicion_score'));
        $this->assertEquals('high', $response->json('suspicion_status'));

        // 4. Another TabSwitchAttempt -> 20 * log2(2+1) = 20 * 1.58 = 31.7
        // Previous contribution was 20. New total contribution for TabSwitch is 31.7.
        // Incremental change is 11.7.
        // 63 + 11.7 = 74.7 -> 75.
        $response = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", ['event_type' => 'TabSwitchAttempt']);
        $this->assertEquals(75, $response->json('suspicion_score'));
        $this->assertEquals('high', $response->json('suspicion_status'));

        // 5. RapidAnswerChange (15) -> 75 + 15 = 90 -> Critical (81+)
        $response = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", ['event_type' => 'RapidAnswerChange']);
        $this->assertEquals(90, $response->json('suspicion_score'));
        $this->assertEquals('critical', $response->json('suspicion_status'));
    }

    public function test_score_is_authoritative_and_ignores_client_points(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $candidate = User::factory()->create(['role' => 'candidate']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'T',
            'duration_minutes' => 60,
            'bcd_enabled' => true,
        ]);
        $session = ExamSession::create([
            'exam_id' => $exam->id,
            'candidate_id' => $candidate->id,
            'status' => 'in_progress',
            'expires_at' => now()->addHour(),
        ]);

        // Attempting to inject points via metadata (which should be ignored by logic)
        $response = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", [
            'event_type' => 'IdlePeriod',
            'metadata' => ['suspicion_points' => 100]
        ]);

        // IdlePeriod = 8.
        $this->assertEquals(8, $response->json('suspicion_score'));
    }

    public function test_score_is_capped_at_100(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $candidate = User::factory()->create(['role' => 'candidate']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'T',
            'duration_minutes' => 60,
            'bcd_enabled' => true,
        ]);
        $session = ExamSession::create(['exam_id' => $exam->id, 'candidate_id' => $candidate->id]);

        // Send many events to reach cap
        for($i=0; $i<10; $i++) {
            $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", ['event_type' => 'DeviceChange']);
            $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", ['event_type' => 'TabSwitchAttempt']);
        }

        $response = $this->actingAs($candidate)->getJson("/api/exam-sessions/{$session->id}/behavior-events");
        $this->assertEquals(100, $response->json('suspicion_score'));
        $this->assertEquals('critical', $response->json('suspicion_status'));
    }
}
