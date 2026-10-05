<?php

namespace Tests\Feature;

use App\Models\Exam;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesTestUsers;
use Tests\TestCase;

class LiveInvigilatorTest extends TestCase
{
    use RefreshDatabase;
    use CreatesTestUsers;

    public function test_live_invigilator_can_list_sessions_with_candidate_and_suspicion_data(): void
    {
        [$examiner] = $this->makeUserWithToken('examiner');
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Invigilator Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
            'status' => 'draft',
            'bcd_enabled' => true,
        ]);
        [, $candidateToken] = $this->makeUserWithToken('candidate', 'watched@test.local');
        $candidateHeaders = $this->authHeaders($candidateToken);
        $sessionId = $this->postJson("/api/exams/{$exam->id}/session", [], $candidateHeaders)
            ->json('session.id');
        $this->postJson(
            "/api/exam-sessions/{$sessionId}/behavior-events",
            ['event_type' => 'focus_lost'],
            $candidateHeaders,
        );

        [, $invigilatorToken] = $this->makeUserWithToken('live_invigilator');
        $response = $this->getJson('/api/exam-sessions', $this->authHeaders($invigilatorToken));

        $response->assertStatus(200);
        $row = collect($response->json('sessions'))->firstWhere('session_id', $sessionId);
        $this->assertNotNull($row);
        $this->assertSame('watched@test.local', $row['candidate_email']);
        // SRS weight for WindowFocusLoss (alias focus_lost) is 18.
        $this->assertSame(18, $row['suspicion_score']);
        $this->assertSame('low', $row['suspicion_status']);
    }

    public function test_candidate_cannot_list_all_sessions(): void
    {
        [, $token] = $this->makeUserWithToken('candidate');

        $this->getJson('/api/exam-sessions', $this->authHeaders($token))->assertStatus(403);
    }

    public function test_institutional_administrator_can_access_oversight_and_management(): void
    {
        [, $token] = $this->makeUserWithToken('institutional_administrator');
        $headers = $this->authHeaders($token);

        $this->getJson('/api/exam-sessions', $headers)->assertStatus(200);
        $this->getJson('/api/users', $headers)->assertStatus(200);
        $this->getJson('/api/analytics/institutional', $headers)->assertStatus(200);
    }
}
