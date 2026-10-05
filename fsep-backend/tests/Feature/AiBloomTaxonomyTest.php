<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\User;
use App\Models\Question;
use App\Services\AiQuestionGeneratorService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Mockery;
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
        $this->instance(
            AiQuestionGeneratorService::class,
            Mockery::mock(AiQuestionGeneratorService::class, function ($mock) {
                $mock->shouldReceive('generate')->andReturn([[
                    'question_text' => 'Generated MCQ',
                    'question_type' => 'mcq',
                    'marks' => 5,
                    'difficulty' => 'medium',
                    'bloom_taxonomy' => 'analyze',
                    'topic_tag' => 'AI',
                    'options' => ['A', 'B', 'C', 'D'],
                    'correct_answer' => 'A',
                    'is_ai_generated' => true
                ]]);
            })
        );

        $response = $this->actingAs($this->examiner)->postJson('/api/questions/generate', [
            'exam_ids' => [$this->exam->id],
            'topic' => 'Neural Networks',
            'question_types' => ['mcq'],
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'analyze',
            'count' => 1,
            'marks' => 5
        ]);

        $response->assertStatus(200);
        $response->assertJsonFragment([
            'bloom_taxonomy' => 'analyze',
            'marks' => 5
        ]);
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
