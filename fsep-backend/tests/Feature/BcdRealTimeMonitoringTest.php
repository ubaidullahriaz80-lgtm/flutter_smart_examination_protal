<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BcdRealTimeMonitoringTest extends TestCase
{
    use RefreshDatabase;

    public function test_behavioral_dashboard_route_is_protected(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'T', 'duration_minutes' => 60]);

        // Unauthenticated
        $this->getJson("/api/exams/{$exam->id}/behavioral-dashboard")->assertStatus(401);

        // Candidate
        $candidate = User::factory()->create(['role' => 'candidate']);
        $this->actingAs($candidate)->getJson("/api/exams/{$exam->id}/behavioral-dashboard")->assertStatus(403);
    }

    public function test_authorized_staff_can_access_dashboard(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'T', 'duration_minutes' => 60]);

        $invigilator = User::factory()->create(['role' => 'live_invigilator']);

        $response = $this->actingAs($invigilator)->get("/api/exams/{$exam->id}/behavioral-dashboard");

        $response->assertStatus(200);
        $this->assertStringContainsString('text/event-stream', $response->headers->get('Content-Type'));
    }
}
