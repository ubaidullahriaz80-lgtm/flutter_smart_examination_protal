<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\ExamSession;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExamBcdToggleTest extends TestCase
{
    use RefreshDatabase;

    public function test_examiner_can_configure_bcd_enabled(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);

        // Default should be true
        $response = $this->actingAs($examiner)->postJson('/api/exams', [
            'title' => 'BCD Config Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
            'status' => 'draft',
            'bcd_enabled' => false
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('exams', [
            'title' => 'BCD Config Exam',
            'bcd_enabled' => false
        ]);
    }

    public function test_bcd_events_rejected_if_disabled(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'No BCD Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'status' => 'published',
            'bcd_enabled' => false
        ]);

        $candidate = User::factory()->create(['role' => 'candidate']);
        $session = ExamSession::create([
            'exam_id' => $exam->id,
            'candidate_id' => $candidate->id,
            'status' => 'in_progress',
            'started_at' => now(),
            'expires_at' => now()->addHour()
        ]);

        $response = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", [
            'event_type' => 'focus_lost'
        ]);

        $response->assertStatus(422);
        $response->assertJsonFragment(['message' => 'Behavioral Cheating Detection is disabled for this exam.']);
    }

    public function test_bcd_events_processed_if_enabled(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'BCD Enabled Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'status' => 'published',
            'bcd_enabled' => true
        ]);

        $candidate = User::factory()->create(['role' => 'candidate']);
        $session = ExamSession::create([
            'exam_id' => $exam->id,
            'candidate_id' => $candidate->id,
            'status' => 'in_progress',
            'started_at' => now(),
            'expires_at' => now()->addHour()
        ]);

        $response = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", [
            'event_type' => 'focus_lost'
        ]);

        $response->assertStatus(201);
    }
}
