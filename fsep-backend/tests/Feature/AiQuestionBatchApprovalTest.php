<?php

namespace Tests\Feature;

use App\Models\AiQuestionGenerationJob;
use App\Models\Exam;
use App\Models\Question;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AiQuestionBatchApprovalTest extends TestCase
{
    use RefreshDatabase;

    public function test_examiner_can_bulk_approve_questions(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
            'status' => 'published',
        ]);

        $job = AiQuestionGenerationJob::create([
            'examiner_id' => $examiner->id,
            'status' => 'REVIEW_PENDING',
            'questions_generated' => 2
        ]);

        $q1 = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'generation_job_id' => $job->id,
            'question_text' => 'Q1',
            'question_type' => 'mcq',
            'marks' => 5,
            'is_ai_generated' => true,
            'review_status' => 'pending',
            'options' => ['A', 'B'],
            'correct_answer' => 'A'
        ]);

        $q2 = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'generation_job_id' => $job->id,
            'question_text' => 'Q2',
            'question_type' => 'mcq',
            'marks' => 5,
            'is_ai_generated' => true,
            'review_status' => 'pending',
            'options' => ['A', 'B'],
            'correct_answer' => 'A'
        ]);

        $response = $this->actingAs($examiner)->postJson('/api/questions/generate/approve', [
            'question_ids' => [$q1->id, $q2->id],
            'action' => 'approve'
        ]);

        $response->assertStatus(200);
        $response->assertJson(['approved_count' => 2]);

        $q1->refresh();
        $q2->refresh();
        $job->refresh();

        $this->assertEquals('approved', $q1->review_status);
        $this->assertEquals('approved', $q2->review_status);
        $this->assertEquals($examiner->id, $q1->reviewed_by);
        $this->assertEquals(2, $job->questions_approved);
        $this->assertEquals('COMPLETED', $job->status);
    }

    public function test_bulk_rejection_requires_reason(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'E', 'duration_minutes' => 60]);
        $job = AiQuestionGenerationJob::create(['examiner_id' => $examiner->id, 'status' => 'REVIEW_PENDING', 'questions_generated' => 1]);
        $q = Question::create([
            'exam_id' => $exam->id, 'created_by' => $examiner->id, 'generation_job_id' => $job->id,
            'question_text' => 'Q', 'question_type' => 'mcq', 'marks' => 5, 'review_status' => 'pending'
        ]);

        $response = $this->actingAs($examiner)->postJson('/api/questions/generate/approve', [
            'question_ids' => [$q->id],
            'action' => 'reject'
        ]);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors(['rejection_reason']);

        $response = $this->actingAs($examiner)->postJson('/api/questions/generate/approve', [
            'question_ids' => [$q->id],
            'action' => 'reject',
            'rejection_reason' => 'Bad questions'
        ]);

        $response->assertStatus(200);
        $q->refresh();
        $this->assertEquals('rejected', $q->review_status);
        $this->assertEquals('Bad questions', $q->rejection_reason);
    }

    public function test_unauthorized_examiner_cannot_bulk_approve(): void
    {
        $examiner1 = User::factory()->create(['role' => 'examiner']);
        $examiner2 = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner1->id, 'title' => 'E', 'duration_minutes' => 60]);
        $job = AiQuestionGenerationJob::create(['examiner_id' => $examiner1->id]);
        $q = Question::create([
            'exam_id' => $exam->id, 'created_by' => $examiner1->id, 'generation_job_id' => $job->id,
            'question_text' => 'Q', 'question_type' => 'mcq', 'marks' => 5, 'review_status' => 'pending'
        ]);

        $response = $this->actingAs($examiner2)->postJson('/api/questions/generate/approve', [
            'question_ids' => [$q->id],
            'action' => 'approve'
        ]);

        $response->assertStatus(403);
    }
}
