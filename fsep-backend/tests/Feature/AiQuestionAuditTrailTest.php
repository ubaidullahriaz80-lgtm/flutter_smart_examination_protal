<?php

namespace Tests\Feature;

use App\Models\AiQuestionGenerationJob;
use App\Models\Exam;
use App\Models\Question;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AiQuestionAuditTrailTest extends TestCase
{
    use RefreshDatabase;

    public function test_approving_a_question_increments_job_counter(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $job = AiQuestionGenerationJob::create([
            'examiner_id' => $examiner->id,
            'status' => 'REVIEW_PENDING',
            'questions_generated' => 1
        ]);

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

        $this->actingAs($examiner)->putJson("/api/questions/{$question->id}", [
            'exam_id' => $exam->id,
            'question_text' => 'AI Question',
            'question_type' => 'mcq',
            'marks' => 5,
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'understand',
            'options' => ['A', 'B'],
            'correct_answer' => 'A',
            'review_status' => 'approved',
        ]);

        $job->refresh();
        $this->assertEquals(1, $job->questions_approved);
        $this->assertEquals(0, $job->questions_rejected);
    }

    public function test_editing_a_question_sets_is_edited_flag(): void
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
            'question_text' => 'Original Text',
            'question_type' => 'mcq',
            'marks' => 5,
            'is_ai_generated' => true,
            'review_status' => 'pending',
            'options' => ['A', 'B'],
            'correct_answer' => 'A'
        ]);

        $this->actingAs($examiner)->putJson("/api/questions/{$question->id}", [
            'exam_id' => $exam->id,
            'question_text' => 'Modified Text',
            'question_type' => 'mcq',
            'marks' => 5,
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'understand',
            'options' => ['A', 'B'],
            'correct_answer' => 'A',
            'review_status' => 'pending',
        ]);

        $question->refresh();
        $this->assertTrue($question->is_edited);
    }

    public function test_state_timestamps_are_recorded(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $job = AiQuestionGenerationJob::create([
            'examiner_id' => $examiner->id,
            'status' => 'UPLOADING',
        ]);

        $job->update([
            'status' => 'PARSING',
            'parsing_at' => now(),
        ]);

        $job->refresh();
        $this->assertNotNull($job->parsing_at);
    }
}
