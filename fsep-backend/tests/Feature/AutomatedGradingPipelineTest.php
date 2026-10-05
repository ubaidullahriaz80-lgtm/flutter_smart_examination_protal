<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\Question;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AutomatedGradingPipelineTest extends TestCase
{
    use RefreshDatabase;

    public function test_final_submission_generates_and_exposes_result(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Automated Grading Test',
            'duration_minutes' => 60,
            'total_marks' => 10,
        ]);

        $question = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => '2+2?',
            'question_type' => 'mcq',
            'marks' => 10,
            'options' => ['4', '5'],
            'correct_answer' => '4',
            'review_status' => 'approved',
        ]);

        $candidate = User::factory()->create(['role' => 'candidate']);
        $sessionResponse = $this->actingAs($candidate)->postJson("/api/exams/{$exam->id}/session");
        $sessionId = $sessionResponse->json('session.id');

        // Submit answer
        $this->actingAs($candidate)->putJson("/api/exam-sessions/{$sessionId}/answers/{$question->id}", [
            'selected_option' => '4'
        ]);

        // 1. Submit exam (triggers pipeline)
        $submitResponse = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$sessionId}/submit");
        $submitResponse->assertStatus(200);

        // 2. Verify result persistence
        $this->assertDatabaseHas('results', [
            'exam_session_id' => $sessionId,
            'total_score' => 10,
            'status' => 'graded',
        ]);

        // 3. Verify availability via reporting endpoint (workflow)
        $reportResponse = $this->actingAs($candidate)->getJson("/api/results/{$sessionId}");
        $reportResponse->assertStatus(200)
            ->assertJsonPath('result.total_score', 10)
            ->assertJsonPath('result.status', 'graded');

        // 4. Verify security (unauthorized candidate)
        $otherCandidate = User::factory()->create(['role' => 'candidate']);
        $this->actingAs($otherCandidate)->getJson("/api/results/{$sessionId}")
            ->assertStatus(403);
    }
}
