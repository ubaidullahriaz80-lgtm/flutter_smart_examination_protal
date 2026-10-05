<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\ExamSession;
use App\Models\Result;
use App\Models\User;
use App\Models\BehaviorEvent;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class InstitutionalAnalyticsFrRa02Test extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_access_detailed_institutional_analytics(): void
    {
        $admin = User::factory()->create(['role' => 'system_administrator']);

        // Create 2 other candidates (total 2)
        User::factory()->count(2)->create(['role' => 'candidate']);

        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'T', 'duration_minutes' => 60]);

        $candidate = User::factory()->create(['role' => 'candidate']); // total 3 candidates + 1 from s2 = 4 total candidates

        // Session 1: 10 mins
        $s1 = ExamSession::create([
            'exam_id' => $exam->id,
            'candidate_id' => $candidate->id,
            'status' => 'submitted',
            'started_at' => now()->subMinutes(10),
            'submitted_at' => now()
        ]);
        Result::create(['exam_session_id' => $s1->id, 'total_score' => 80, 'max_score' => 100, 'status' => 'graded', 'graded_at' => now()]);

        // Session 2: 20 mins, unreliable (device change)
        $s2 = ExamSession::create([
            'exam_id' => $exam->id,
            'candidate_id' => User::factory()->create(['role' => 'candidate'])->id,
            'status' => 'submitted',
            'started_at' => now()->subMinutes(20),
            'submitted_at' => now()
        ]);
        Result::create(['exam_session_id' => $s2->id, 'total_score' => 60, 'max_score' => 100, 'status' => 'graded', 'graded_at' => now()]);
        BehaviorEvent::create([
            'exam_session_id' => $s2->id,
            'candidate_id' => $s2->candidate_id,
            'event_type' => 'DeviceChange',
            'severity' => 'HIGH',
            'event_timestamp' => now()
        ]);

        $response = $this->actingAs($admin)->getJson('/api/analytics/cohort');

        $response->assertStatus(200);

        // Completion Rate: 2 unique candidates submitted / 4 total candidates = 50.0%
        $response->assertJsonPath('summary.completion_rate', 50);

        // Median Completion Time: median(10, 20) = 15.0
        $response->assertJsonPath('summary.median_completion_time', 15);

        // Device Reliability: 1/2 reliable sessions = 50.0%
        $response->assertJsonPath('device_reliability.reliability_rate', 50);

        // Risk Distribution
        $response->assertJsonStructure(['behavioral_risk_distribution']);
    }

    public function test_candidate_cannot_access_institutional_analytics(): void
    {
        $candidate = User::factory()->create(['role' => 'candidate']);
        $this->actingAs($candidate)->getJson('/api/analytics/cohort')->assertStatus(403);
    }
}
