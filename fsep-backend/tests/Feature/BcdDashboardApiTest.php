<?php

namespace Tests\Feature;

use App\Models\BehavioralRiskScore;
use App\Models\Exam;
use App\Models\ExamSession;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BcdDashboardApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_staff_can_view_real_time_dashboard_data(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'T',
            'duration_minutes' => 60,
            'bcd_enabled' => true,
        ]);

        $candidate = User::factory()->create(['role' => 'candidate']);
        $session = ExamSession::create([
            'exam_id' => $exam->id,
            'candidate_id' => $candidate->id,
            'status' => 'in_progress',
        ]);

        BehavioralRiskScore::create([
            'exam_session_id' => $session->id,
            'risk_score' => 45,
            'risk_band' => 'medium',
            'computed_at' => now(),
            'event_breakdown' => ['focus_lost' => ['count' => 3]]
        ]);

        $invigilator = User::factory()->create(['role' => 'live_invigilator']);

        // We can't easily test the full SSE loop in a single request,
        // but we can test that the endpoint responds with 200 and correct headers.
        $response = $this->actingAs($invigilator)->get("/api/exams/{$exam->id}/behavioral-dashboard");

        $response->assertStatus(200);
        $this->assertStringContainsString('text/event-stream', $response->headers->get('Content-Type'));
    }
}
