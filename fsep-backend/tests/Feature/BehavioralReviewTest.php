<?php

namespace Tests\Feature;

use App\Models\BehaviorEvent;
use App\Models\Exam;
use App\Models\ExamSession;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BehavioralReviewTest extends TestCase
{
    use RefreshDatabase;

    public function test_staff_can_review_behavioral_event(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'T', 'duration_minutes' => 60]);
        $candidate = User::factory()->create(['role' => 'candidate']);
        $session = ExamSession::create(['exam_id' => $exam->id, 'candidate_id' => $candidate->id, 'status' => 'in_progress']);

        $event = BehaviorEvent::create([
            'exam_session_id' => $session->id,
            'client_uuid' => 'uuid-123',
            'candidate_id' => $candidate->id,
            'event_type' => 'focus_lost',
            'severity' => 'HIGH',
            'event_timestamp' => now(),
            'suspicion_points' => 18,
        ]);

        $invigilator = User::factory()->create(['role' => 'live_invigilator']);

        $response = $this->actingAs($invigilator)->postJson('/api/behavioral/review', [
            'event_id' => $event->id,
            'action' => 'Escalated',
            'note' => 'Candidate looked away multiple times.',
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('behavioral_review_actions', [
            'event_id' => $event->id,
            'invigilator_id' => $invigilator->id,
            'action' => 'Escalated',
        ]);
    }

    public function test_candidate_cannot_review_behavioral_event(): void
    {
        $candidate = User::factory()->create(['role' => 'candidate']);
        $event = BehaviorEvent::factory()->create();

        $this->actingAs($candidate)->postJson('/api/behavioral/review', [
            'event_id' => $event->id,
            'action' => 'Reviewed',
        ])->assertStatus(403);
    }
}
