<?php

namespace Tests\Feature;

use App\Models\AiQuestionGenerationJob;
use App\Models\Exam;
use App\Models\Question;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AiQuestionReviewWorkflowTest extends TestCase
{
    use RefreshDatabase;

    public function test_examiner_can_retrieve_review_queue(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $job = AiQuestionGenerationJob::create(['examiner_id' => $examiner->id, 'status' => 'REVIEW_PENDING']);

        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
            'status' => 'published',
        ]);

        $question = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'generation_job_id' => $job->id,
            'question_text' => 'AI Question',
            'question_type' => 'mcq',
            'marks' => 5,
            'is_ai_generated' => true,
            'review_status' => 'pending',
            'options' => ['A', 'B'],
            'correct_answer' => 'A'
        ]);

        $response = $this->actingAs($examiner)->getJson("/api/questions/generate/review/{$job->id}");

        $response->assertStatus(200);
        $response->assertJsonCount(1, 'questions');
        $this->assertEquals($question->id, $response->json('questions.0.id'));
    }

    public function test_unauthorized_examiner_cannot_retrieve_another_examiners_queue(): void
    {
        $examiner1 = User::factory()->create(['role' => 'examiner']);
        $examiner2 = User::factory()->create(['role' => 'examiner']);
        $job = AiQuestionGenerationJob::create(['examiner_id' => $examiner1->id]);

        $response = $this->actingAs($examiner2)->getJson("/api/questions/generate/review/{$job->id}");

        $response->assertStatus(403);
    }

    public function test_approving_a_question_sets_metadata(): void
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

        $question = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'AI Question',
            'question_type' => 'mcq',
            'marks' => 5,
            'is_ai_generated' => true,
            'review_status' => 'pending',
            'options' => ['A', 'B'],
            'correct_answer' => 'A'
        ]);

        $response = $this->actingAs($examiner)->putJson("/api/questions/{$question->id}", [
            'exam_id' => $exam->id,
            'question_text' => 'Edited Text',
            'question_type' => 'mcq',
            'marks' => 5,
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'understand',
            'options' => ['A', 'B'],
            'correct_answer' => 'A',
            'review_status' => 'approved',
        ]);

        $response->assertStatus(200);
        $question->refresh();
        $this->assertEquals('approved', $question->review_status);
        $this->assertEquals($examiner->id, $question->reviewed_by);
        $this->assertNotNull($question->reviewed_at);
        $this->assertEquals('Edited Text', $question->question_text);
    }

    public function test_rejection_requires_a_reason(): void
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

        $question = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'AI Question',
            'question_type' => 'mcq',
            'marks' => 5,
            'is_ai_generated' => true,
            'review_status' => 'pending',
            'options' => ['A', 'B'],
            'correct_answer' => 'A'
        ]);

        $response = $this->actingAs($examiner)->putJson("/api/questions/{$question->id}", [
            'exam_id' => $exam->id,
            'question_text' => 'Edited Text',
            'question_type' => 'mcq',
            'marks' => 5,
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'understand',
            'options' => ['A', 'B'],
            'correct_answer' => 'A',
            'review_status' => 'rejected',
        ]);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors(['rejection_reason']);

        $response = $this->actingAs($examiner)->putJson("/api/questions/{$question->id}", [
            'exam_id' => $exam->id,
            'question_text' => 'Edited Text',
            'question_type' => 'mcq',
            'marks' => 5,
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'understand',
            'options' => ['A', 'B'],
            'correct_answer' => 'A',
            'review_status' => 'rejected',
            'rejection_reason' => 'Duplicate content',
        ]);

        $response->assertStatus(200);
        $question->refresh();
        $this->assertEquals('rejected', $question->review_status);
        $this->assertEquals('Duplicate content', $question->rejection_reason);
    }
}
