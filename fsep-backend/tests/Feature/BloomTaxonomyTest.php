<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\Question;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BloomTaxonomyTest extends TestCase
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
            'title' => 'Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 100,
            'negative_marking_weight' => 0.25,
            'status' => 'draft'
        ]);
    }

    public function test_can_create_question_with_all_bloom_levels(): void
    {
        $levels = ['remember', 'understand', 'apply', 'analyze', 'evaluate', 'create'];

        foreach ($levels as $level) {
            $response = $this->actingAs($this->examiner)->postJson('/api/questions', [
                'exam_id' => $this->exam->id,
                'question_text' => "Test $level",
                'question_type' => 'mcq',
                'marks' => 1,
                'difficulty' => 'medium',
                'bloom_taxonomy' => $level,
                'options' => ['A', 'B', 'C', 'D'],
                'correct_answer' => 'A'
            ]);

            $response->assertStatus(201);
            $this->assertDatabaseHas('questions', [
                'question_text' => "Test $level",
                'bloom_taxonomy' => $level
            ]);
        }
    }

    public function test_rejects_invalid_bloom_level(): void
    {
        $response = $this->actingAs($this->examiner)->postJson('/api/questions', [
            'exam_id' => $this->exam->id,
            'question_text' => 'Invalid Bloom',
            'question_type' => 'mcq',
            'marks' => 1,
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'invalid_level',
            'options' => ['A', 'B'],
            'correct_answer' => 'A'
        ]);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors(['bloom_taxonomy']);
    }

    public function test_can_update_bloom_level(): void
    {
        $question = Question::create([
            'exam_id' => $this->exam->id,
            'created_by' => $this->examiner->id,
            'question_text' => 'Original Text',
            'question_type' => 'mcq',
            'marks' => 1,
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'remember',
            'options' => ['A', 'B'],
            'correct_answer' => 'A',
            'review_status' => 'pending'
        ]);

        $response = $this->actingAs($this->examiner)->putJson("/api/questions/{$question->id}", [
            'exam_id' => $this->exam->id,
            'question_text' => 'Updated Text',
            'question_type' => 'mcq',
            'marks' => 1,
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'evaluate',
            'review_status' => 'pending',
            'options' => ['A', 'B'],
            'correct_answer' => 'A'
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('questions', [
            'id' => $question->id,
            'bloom_taxonomy' => 'evaluate'
        ]);
    }
}
