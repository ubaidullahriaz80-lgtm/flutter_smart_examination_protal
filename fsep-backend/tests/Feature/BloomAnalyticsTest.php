<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\Question;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BloomAnalyticsTest extends TestCase
{
    use RefreshDatabase;

    protected User $examiner;
    protected User $candidate;
    protected Exam $exam;

    protected function setUp(): void
    {
        parent::setUp();
        $this->examiner = User::factory()->create(['role' => 'examiner']);
        $this->candidate = User::factory()->create(['role' => 'candidate']);
        $this->exam = Exam::create([
            'created_by' => $this->examiner->id,
            'title' => 'Bloom Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 100,
            'negative_marking_weight' => 0,
            'status' => 'published'
        ]);
    }

    public function test_bloom_performance_calculation_across_multiple_levels(): void
    {
        // 1. Create questions at different Bloom levels
        $q1 = $this->createQuestion('fact 1', 'remember', 10);
        $q2 = $this->createQuestion('explain 1', 'understand', 10);
        $q3 = $this->createQuestion('solve 1', 'apply', 10);

        // 2. Start session and answer
        $this->actingAs($this->candidate);
        $sessionResponse = $this->postJson("/api/exams/{$this->exam->id}/session");
        $sessionId = $sessionResponse->json('session.id');

        // Remember: Correct (100%)
        // Understand: Wrong (0%)
        // Apply: Correct (100%)
        // Others: N/A
        $this->submitAnswer($sessionId, $q1->id, 'Correct');
        $this->submitAnswer($sessionId, $q2->id, 'Wrong');
        $this->submitAnswer($sessionId, $q3->id, 'Correct');

        $this->postJson("/api/exam-sessions/{$sessionId}/submit");

        // 3. Verify LGD Report
        $response = $this->getJson('/api/learning-gaps');
        $response->assertStatus(200);

        $bloom = $response->json('bloom_profile');

        $this->assertEquals(100, $bloom['Remember']);
        $this->assertEquals(0, $bloom['Understand']);
        $this->assertEquals(100, $bloom['Apply']);
        $this->assertNull($bloom['Analyze']);
        $this->assertNull($bloom['Evaluate']);
        $this->assertNull($bloom['Create']);
    }

    public function test_bloom_analytics_persists_in_database(): void
    {
        $q1 = $this->createQuestion('fact 1', 'remember', 10);
        $this->actingAs($this->candidate);
        $sessionId = $this->postJson("/api/exams/{$this->exam->id}/session")->json('session.id');
        $this->submitAnswer($sessionId, $q1->id, 'Correct');
        $this->postJson("/api/exam-sessions/{$sessionId}/submit");

        $this->assertDatabaseHas('learning_gap_reports', [
            'exam_session_id' => $sessionId,
            'candidate_id' => $this->candidate->id
        ]);

        $report = \App\Models\LearningGapReport::where('exam_session_id', $sessionId)->first();
        $this->assertArrayHasKey('Remember', $report->bloom_profile);
        $this->assertEquals(100, $report->bloom_profile['Remember']);
    }

    private function createQuestion(string $text, string $bloom, int $marks): Question
    {
        return Question::create([
            'exam_id' => $this->exam->id,
            'created_by' => $this->examiner->id,
            'question_text' => $text,
            'question_type' => 'mcq',
            'marks' => $marks,
            'difficulty' => 'medium',
            'bloom_taxonomy' => $bloom,
            'topic_tag' => 'Testing',
            'options' => ['Correct', 'Wrong'],
            'correct_answer' => 'Correct',
            'review_status' => 'approved'
        ]);
    }

    private function submitAnswer(int $sessionId, int $questionId, string $option): void
    {
        $this->putJson("/api/exam-sessions/{$sessionId}/answers/{$questionId}", [
            'selected_option' => $option
        ]);
    }
}
