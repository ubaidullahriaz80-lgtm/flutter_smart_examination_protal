<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\Question;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesTestUsers;
use Tests\TestCase;

class CohortAnalyticsTest extends TestCase
{
    use RefreshDatabase;
    use CreatesTestUsers;

    public function test_candidate_is_forbidden_from_cohort_analytics(): void
    {
        [, $token] = $this->makeUserWithToken('candidate');

        $this->getJson('/api/analytics/cohort', $this->authHeaders($token))->assertStatus(403);
    }

    public function test_summary_reflects_real_submitted_sessions(): void
    {
        [$examiner] = $this->makeUserWithToken('examiner');
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Analytics Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
            'status' => 'draft',
        ]);
        $question = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => '2 + 2 = ?',
            'question_type' => 'mcq',
            'marks' => 10,
            'difficulty' => 'easy',
            'bloom_taxonomy' => 'remember',
            'options' => ['3', '4', '5'],
            'correct_answer' => '4',
            'is_ai_generated' => false,
            'review_status' => 'approved',
        ]);

        // Two candidates: one scores 100%, one scores 0%. Deliberately a
        // plain indexed array, not ['4' => ..., '3' => ...] — PHP casts
        // numeric-string array keys to int, which would then fail the
        // backend's 'string' validation rule for selected_option.
        foreach (['4', '3'] as $answer) {
            [, $token] = $this->makeUserWithToken('candidate');
            $headers = $this->authHeaders($token);
            $sessionId = $this->postJson("/api/exams/{$exam->id}/session", [], $headers)
                ->json('session.id');
            $this->putJson(
                "/api/exam-sessions/{$sessionId}/answers/{$question->id}",
                ['selected_option' => $answer],
                $headers,
            )->assertStatus(200);
            $this->postJson("/api/exam-sessions/{$sessionId}/submit", [], $headers);
        }

        [, $examinerToken] = $this->makeUserWithToken('examiner', 'analytics-viewer@test.local');
        $response = $this->getJson(
            "/api/analytics/cohort?exam_id={$exam->id}",
            $this->authHeaders($examinerToken),
        );

        $response->assertStatus(200)->assertJson([
            'summary' => [
                'exam_id' => $exam->id,
                'candidate_count' => 2,
                'submission_count' => 2,
                'average_percentage' => 50.0,
                'highest_percentage' => 100.0,
                'lowest_percentage' => 0.0,
            ],
        ]);
    }
}
