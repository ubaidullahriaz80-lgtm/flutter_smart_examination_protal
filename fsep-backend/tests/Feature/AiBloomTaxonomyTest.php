<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\AiQuestionGenerationJob;
use App\Models\User;
use App\Models\Question;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class AiBloomTaxonomyTest extends TestCase
{
    use RefreshDatabase;

    protected User $examiner;
    protected Exam $exam;

    protected function setUp(): void
    {
        parent::setUp();
        $this->examiner = User::factory()->create(['role' => 'examiner']);
        $this->exam = Exam::create([
            'created_by' => $this->examiner->id,
            'title' => 'Biology 101',
            'duration_minutes' => 60,
            'total_marks' => 100,
            'negative_marking_weight' => 0.25,
            'status' => 'draft'
        ]);
    }

    public function test_ai_generation_request_validates_bloom_and_marks(): void
    {
        Queue::fake();

        $response = $this->actingAs($this->examiner)->postJson('/api/questions/generate', [
            'exam_ids' => [$this->exam->id],
            'topic' => 'Neural Networks',
            'question_types' => ['mcq'],
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'analyze',
            'count' => 1,
            'marks' => 5
        ]);

        $response->assertStatus(202)->assertJson(['status' => 'GENERATING']);
        $job = AiQuestionGenerationJob::findOrFail($response->json('job_id'));
        $this->assertSame('analyze', $job->params['bloom_taxonomy']);
        $this->assertSame(5, $job->params['marks']);
    }

    public function test_ai_generated_question_schema_consistency(): void
    {
        $question = Question::create([
            'exam_id' => $this->exam->id,
            'created_by' => $this->examiner->id,
            'question_text' => 'AI Question',
            'question_type' => 'mcq',
            'marks' => 2,
            'difficulty' => 'hard',
            'bloom_taxonomy' => 'create',
            'options' => ['A', 'B'],
            'correct_answer' => 'A',
            'is_ai_generated' => true,
            'review_status' => 'pending'
        ]);

        $this->assertEquals('create', $question->bloom_taxonomy);
        $this->assertEquals(2, $question->marks);
        $this->assertTrue($question->is_ai_generated);
    }
}
