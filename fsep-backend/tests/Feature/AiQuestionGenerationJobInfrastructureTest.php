<?php

namespace Tests\Feature;

use App\Models\AiQuestionGenerationJob;
use App\Models\Exam;
use App\Models\Question;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AiQuestionGenerationJobInfrastructureTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_generation_job_can_be_created_with_examiner_relationship(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);

        $job = AiQuestionGenerationJob::create([
            'examiner_id' => $examiner->id,
            'document_name' => 'syllabus.pdf',
            'status' => 'UPLOADING',
            'questions_generated' => 0,
        ]);

        $this->assertDatabaseHas('ai_question_generation_jobs', [
            'id' => $job->id,
            'examiner_id' => $examiner->id,
            'document_name' => 'syllabus.pdf',
            'status' => 'UPLOADING',
        ]);

        $this->assertInstanceOf(User::class, $job->examiner);
        $this->assertEquals($examiner->id, $job->examiner->id);
    }

    public function test_generated_questions_can_be_linked_to_job(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
            'status' => 'draft',
        ]);

        $job = AiQuestionGenerationJob::create([
            'examiner_id' => $examiner->id,
            'status' => 'COMPLETED',
            'questions_generated' => 1,
        ]);

        $question = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'Sample AI Question',
            'question_type' => 'mcq',
            'marks' => 5,
            'is_ai_generated' => true,
            'generation_job_id' => $job->id,
            'review_status' => 'pending',
        ]);

        $this->assertCount(1, $job->questions);
        $this->assertEquals($question->id, $job->questions->first()->id);
        $this->assertEquals($job->id, $question->generationJob->id);
    }

    public function test_existing_questions_without_job_id_still_work(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
            'status' => 'draft',
        ]);

        $question = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'Manual Question',
            'question_type' => 'mcq',
            'marks' => 5,
            'is_ai_generated' => false,
            'review_status' => 'approved',
        ]);

        $this->assertNull($question->generation_job_id);
        $this->assertDatabaseHas('questions', [
            'id' => $question->id,
            'generation_job_id' => null,
        ]);
    }

    public function test_review_fields_in_questions_table(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
            'status' => 'draft',
        ]);

        $question = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'AI Question',
            'question_type' => 'mcq',
            'marks' => 5,
            'is_ai_generated' => true,
            'review_status' => 'rejected',
            'reviewed_by' => $examiner->id,
            'reviewed_at' => now(),
            'rejection_reason' => 'Poor quality',
        ]);

        $this->assertDatabaseHas('questions', [
            'id' => $question->id,
            'reviewed_by' => $examiner->id,
            'rejection_reason' => 'Poor quality',
        ]);

        $this->assertInstanceOf(User::class, $question->reviewer);
    }
}
