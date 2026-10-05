<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\Question;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CodeGradingTest extends TestCase
{
    use RefreshDatabase;

    public function test_examiner_can_create_code_question_with_test_cases(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Programming 101',
            'duration_minutes' => 60,
            'total_marks' => 100,
        ]);

        $response = $this->actingAs($examiner)->postJson('/api/questions', [
            'exam_id' => $exam->id,
            'question_text' => 'Write a function that prints Hello World',
            'question_type' => 'code_snippet',
            'marks' => 10,
            'difficulty' => 'easy',
            'bloom_taxonomy' => 'apply',
            'options' => ['python'],
            'test_cases' => [
                ['input' => '', 'expected_output' => 'Hello World']
            ]
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('questions', [
            'question_type' => 'code_snippet',
            'marks' => 10
        ]);

        $question = Question::where('question_type', 'code_snippet')->first();
        $this->assertCount(1, $question->test_cases);
        $this->assertEquals('Hello World', $question->test_cases[0]['expected_output']);
    }

    public function test_correct_code_receives_full_marks(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Programming 101',
            'duration_minutes' => 60,
            'total_marks' => 10,
        ]);

        $question = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'Print 5',
            'question_type' => 'code_snippet',
            'marks' => 10,
            'difficulty' => 'easy',
            'bloom_taxonomy' => 'apply',
            'options' => ['python'],
            'review_status' => 'approved',
            'test_cases' => [
                ['input' => '', 'expected_output' => '5']
            ]
        ]);

        $candidate = User::factory()->create(['role' => 'candidate']);
        $sessionResponse = $this->actingAs($candidate)->postJson("/api/exams/{$exam->id}/session");
        $sessionId = $sessionResponse->json('session.id');

        // Submit correct code
        $this->actingAs($candidate)->putJson("/api/exam-sessions/{$sessionId}/answers/{$question->id}", [
            'selected_option' => "print('5')"
        ]);

        // Submit exam
        $submitResponse = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$sessionId}/submit");
        $submitResponse->assertStatus(200);

        // Verify marks
        $this->assertEquals(10, $submitResponse->json('result.total_score'));
        $this->assertEquals('graded', $submitResponse->json('result.status'));

        // Verify metadata (FR-AG-03: scoring vector, runtime traces)
        $answer = \App\Models\Answer::where('exam_session_id', $sessionId)->first();
        $this->assertNotNull($answer->grading_metadata);
        $this->assertArrayHasKey('scoring_vector', $answer->grading_metadata);
        $this->assertCount(1, $answer->grading_metadata['scoring_vector']);
        $this->assertTrue($answer->grading_metadata['scoring_vector'][0]['passed']);
        $this->assertEquals('5', $answer->grading_metadata['scoring_vector'][0]['stdout']);
        $this->assertTrue($answer->grading_metadata['scoring_vector'][0]['is_mock']);
    }

    public function test_incorrect_code_receives_negative_marks(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Programming 101',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0.5, // 50% penalty
        ]);

        $question = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'Print 5',
            'question_type' => 'code_snippet',
            'marks' => 10,
            'difficulty' => 'easy',
            'bloom_taxonomy' => 'apply',
            'options' => ['python'],
            'review_status' => 'approved',
            'test_cases' => [
                ['input' => '', 'expected_output' => '5']
            ]
        ]);

        $candidate = User::factory()->create(['role' => 'candidate']);
        $sessionResponse = $this->actingAs($candidate)->postJson("/api/exams/{$exam->id}/session");
        $sessionId = $sessionResponse->json('session.id');

        // Submit wrong code
        $this->actingAs($candidate)->putJson("/api/exam-sessions/{$sessionId}/answers/{$question->id}", [
            'selected_option' => "print('6')"
        ]);

        $submitResponse = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$sessionId}/submit");

        // Penalty: - (10 * 0.5) = -5
        $this->assertEquals(-5, $submitResponse->json('result.total_score'));
    }

    public function test_unsupported_language_reverts_to_manual_review(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'E', 'duration_minutes' => 60, 'total_marks' => 10, 'negative_marking_weight' => 0]);

        $question = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'Q',
            'question_type' => 'code_snippet',
            'marks' => 10,
            'options' => ['cobol'], // Unsupported
            'review_status' => 'approved',
            'test_cases' => [['expected_output' => '1']]
        ]);

        $candidate = User::factory()->create(['role' => 'candidate']);
        $sessionId = $this->actingAs($candidate)->postJson("/api/exams/{$exam->id}/session")->json('session.id');
        $this->actingAs($candidate)->putJson("/api/exam-sessions/{$sessionId}/answers/{$question->id}", ['selected_option' => 'code']);

        $response = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$sessionId}/submit");

        $response->assertStatus(200);
        $this->assertEquals('pending_manual_review', $response->json('result.status'));
    }
}
