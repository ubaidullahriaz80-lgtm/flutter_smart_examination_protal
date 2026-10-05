<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\Question;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ShortAnswerGradingTest extends TestCase
{
    use RefreshDatabase;

    public function test_exact_match_succeeds_case_insensitive(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'E1', 'duration_minutes' => 60]);

        $q = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'Q1',
            'question_type' => 'short_answer',
            'correct_answer' => 'Paris',
            'marks' => 10,
            'review_status' => 'approved',
        ]);

        $candidate = User::factory()->create(['role' => 'candidate']);
        $sessionId = $this->actingAs($candidate)->postJson("/api/exams/{$exam->id}/session")->json('session.id');

        $this->actingAs($candidate)->putJson("/api/exam-sessions/{$sessionId}/answers/{$q->id}", ['selected_option' => 'paris']);
        $response = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$sessionId}/submit");

        $response->assertStatus(200);
        $this->assertEquals(10, $response->json('result.total_score'));
    }

    public function test_regex_match_succeeds(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'E1', 'duration_minutes' => 60]);

        $q = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'Q1',
            'question_type' => 'short_answer',
            'regex_patterns' => ['/^\d+$/'],
            'marks' => 10,
            'review_status' => 'approved',
        ]);

        $candidate = User::factory()->create(['role' => 'candidate']);
        $sessionId = $this->actingAs($candidate)->postJson("/api/exams/{$exam->id}/session")->json('session.id');

        $this->actingAs($candidate)->putJson("/api/exam-sessions/{$sessionId}/answers/{$q->id}", ['selected_option' => '123']);
        $response = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$sessionId}/submit");

        $this->assertEquals(10, $response->json('result.total_score'));
    }

    public function test_keyword_match_succeeds(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'E1', 'duration_minutes' => 60]);

        $q = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'Q1',
            'question_type' => 'short_answer',
            'keywords' => ['oxygen', 'hydrogen'],
            'marks' => 10,
            'review_status' => 'approved',
        ]);

        $candidate = User::factory()->create(['role' => 'candidate']);
        $sessionId = $this->actingAs($candidate)->postJson("/api/exams/{$exam->id}/session")->json('session.id');

        $this->actingAs($candidate)->putJson("/api/exam-sessions/{$sessionId}/answers/{$q->id}", ['selected_option' => 'Contains oxygen and stuff']);
        $response = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$sessionId}/submit");

        $this->assertEquals(10, $response->json('result.total_score'));
    }

    public function test_unmatched_answer_falls_back_to_manual_review(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'E1', 'duration_minutes' => 60, 'negative_marking_weight' => 0.5]);

        $q = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'Q1',
            'question_type' => 'short_answer',
            'correct_answer' => 'Correct',
            'marks' => 10,
            'review_status' => 'approved',
        ]);

        $candidate = User::factory()->create(['role' => 'candidate']);
        $sessionId = $this->actingAs($candidate)->postJson("/api/exams/{$exam->id}/session")->json('session.id');

        $this->actingAs($candidate)->putJson("/api/exam-sessions/{$sessionId}/answers/{$q->id}", ['selected_option' => 'Totally Wrong']);
        $response = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$sessionId}/submit");

        $this->assertEquals('pending_manual_review', $response->json('result.status'));
        // 0 marks, NOT negative marks
        $this->assertEquals(0, $response->json('result.total_score'));
    }

    public function test_api_validates_regex(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'E', 'duration_minutes' => 60]);

        $response = $this->actingAs($examiner)->postJson('/api/questions', [
            'exam_id' => $exam->id,
            'question_text' => 'Q',
            'question_type' => 'short_answer',
            'marks' => 10,
            'difficulty' => 'easy',
            'bloom_taxonomy' => 'remember',
            'regex_patterns' => ['[invalid regex'],
        ]);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors('regex_patterns.0');
    }
}
