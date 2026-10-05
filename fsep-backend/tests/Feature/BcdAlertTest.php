<?php

namespace Tests\Feature;

use App\Models\BehavioralAlert;
use App\Models\Exam;
use App\Models\ExamSession;
use App\Models\User;
use App\Services\FcmService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Mockery;
use Tests\TestCase;

class BcdAlertTest extends TestCase
{
    use RefreshDatabase;

    public function test_alert_is_generated_when_risk_crosses_60(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'T', 'duration_minutes' => 60, 'bcd_enabled' => true]);
        $candidate = User::factory()->create(['role' => 'candidate', 'name' => 'John']);
        $session = ExamSession::create(['exam_id' => $exam->id, 'candidate_id' => $candidate->id, 'status' => 'in_progress', 'expires_at' => now()->addHour()]);

        // Mock FcmService
        $this->instance(FcmService::class, Mockery::mock(FcmService::class, function ($mock) {
            $mock->shouldReceive('sendToUser')->once();
            $mock->shouldReceive('sendToUsers')->once();
        }));

        // 1. Send enough events to reach > 60.
        // DeviceChange (25) + TabSwitchAttempt (20) + WindowFocusLoss (18) = 63.

        $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", ['event_type' => 'DeviceChange']);
        $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", ['event_type' => 'TabSwitchAttempt']);

        // This one should trigger the alert as it crosses 60
        $response = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", ['event_type' => 'WindowFocusLoss']);

        $this->assertEquals(63, $response->json('suspicion_score'));

        $this->assertDatabaseHas('behavioral_alerts', [
            'exam_session_id' => $session->id,
            'candidate_id' => $candidate->id,
            'risk_score' => 63,
        ]);
    }

    public function test_duplicate_alert_is_not_sent_if_already_above_60(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'T', 'duration_minutes' => 60, 'bcd_enabled' => true]);
        $candidate = User::factory()->create(['role' => 'candidate']);
        $session = ExamSession::create(['exam_id' => $exam->id, 'candidate_id' => $candidate->id, 'status' => 'in_progress', 'expires_at' => now()->addHour()]);

        // First alert
        BehavioralAlert::create([
            'exam_session_id' => $session->id,
            'candidate_id' => $candidate->id,
            'risk_score' => 65,
            'risk_band' => 'high',
            'triggered_at' => now()->subMinutes(5),
        ]);

        // Pre-set the score record to > 60
        \App\Models\BehavioralRiskScore::create([
            'exam_session_id' => $session->id,
            'risk_score' => 65,
            'risk_band' => 'high',
            'computed_at' => now()->subMinutes(5),
            'event_breakdown' => []
        ]);

        // Mock FcmService - should NOT be called again
        $this->instance(FcmService::class, Mockery::mock(FcmService::class, function ($mock) {
            $mock->shouldNotReceive('sendToUser');
            $mock->shouldNotReceive('sendToUsers');
        }));

        // Send another event (RapidAnswerChange = 15)
        // 65 + 15 * log2(2) = 65 + 15 = 80. Still High, already > 60.
        $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", ['event_type' => 'RapidAnswerChange']);

        // Only the initial alert should exist
        $this->assertDatabaseCount('behavioral_alerts', 1);
    }

    public function test_staff_can_view_alert_history(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'T', 'duration_minutes' => 60]);
        $candidate = User::factory()->create(['role' => 'candidate', 'name' => 'John']);
        $session = ExamSession::create(['exam_id' => $exam->id, 'candidate_id' => $candidate->id]);

        BehavioralAlert::create([
            'exam_session_id' => $session->id,
            'candidate_id' => $candidate->id,
            'risk_score' => 85,
            'risk_band' => 'critical',
            'triggered_at' => now(),
        ]);

        $invigilator = User::factory()->create(['role' => 'live_invigilator']);
        $response = $this->actingAs($invigilator)->getJson("/api/exams/{$exam->id}/behavioral-alerts");

        $response->assertStatus(200);
        $response->assertJsonCount(1, 'alerts');
        $response->assertJsonPath('alerts.0.candidate_name', 'John');
    }
}
