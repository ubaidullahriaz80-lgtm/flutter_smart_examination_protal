<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\Question;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesTestUsers;
use Tests\TestCase;

/**
 * Novelty #3 — Learning Gap Detection. Verifies real per-topic
 * calculation from actual graded answers, without touching the service.
 */
class LearningGapDetectionTest extends TestCase
{
    use RefreshDatabase;
    use CreatesTestUsers;

    public function test_a_weak_topic_is_reported_with_high_severity_below_50_percent(): void
    {
        [$examiner] = $this->makeUserWithToken('examiner');
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'LGD Test Exam',
            'course_code' => 'CS999',
            'duration_minutes' => 60,
            'total_marks' => 30,
            'negative_marking_weight' => 0, // simplifies the expected math
            'status' => 'draft',
        ]);

        $questions = [];
        foreach (['4', '4', '4'] as $correctAnswer) {
            $questions[] = Question::create([
                'exam_id' => $exam->id,
                'created_by' => $examiner->id,
                'question_text' => '2 + 2 = ?',
                'question_type' => 'mcq',
                'marks' => 10,
                'difficulty' => 'easy',
                'bloom_taxonomy' => 'remember',
                'topic_tag' => 'Basic Arithmetic',
                'options' => ['3', '4', '5'],
                'correct_answer' => $correctAnswer,
                'is_ai_generated' => false,
                'review_status' => 'approved',
            ]);
        }

        [, $token] = $this->makeUserWithToken('candidate');
        $headers = $this->authHeaders($token);
        $sessionId = $this->postJson("/api/exams/{$exam->id}/session", [], $headers)
            ->json('session.id');

        // Correct, wrong, wrong -> 10/30 = 33.3%.
        $answers = ['4', '3', '3'];
        foreach ($questions as $i => $question) {
            $this->putJson(
                "/api/exam-sessions/{$sessionId}/answers/{$question->id}",
                ['selected_option' => $answers[$i]],
                $headers,
            )->assertStatus(200);
        }

        $this->postJson("/api/exam-sessions/{$sessionId}/submit", [], $headers)->assertStatus(200);

        $response = $this->getJson('/api/learning-gaps', $headers);
        $response->assertStatus(200);

        $gap = collect($response->json('learning_gaps'))->firstWhere('topic', 'Basic Arithmetic');
        $this->assertNotNull($gap, 'Expected a reported gap for the weak topic.');
        $this->assertSame('CS999', $gap['course_code']);
        $this->assertSame(3, $gap['questions_attempted']);
        $this->assertSame(1, $gap['correct_answers']);
        $this->assertSame(10.0, (float) $gap['obtained_marks']);
        $this->assertSame(30.0, (float) $gap['total_marks']);
        $this->assertSame('high', $gap['severity']);

        // FR-LGD-02: Bloom Profile
        $response->assertJsonStructure(['bloom_profile' => ['Remember', 'Understand', 'Apply']]);
        $this->assertEquals(33.3, $response->json('bloom_profile.Remember'));

        // FR-LGD-03: Difficulty Profile
        $response->assertJsonStructure(['difficulty_profile' => ['Easy', 'Medium', 'Hard']]);
        $this->assertEquals(33.3, $response->json('difficulty_profile.Easy'));

        // FR-LGD-04: Roadmap
        $response->assertJsonStructure(['improvement_roadmap' => [['rank', 'topic', 'suggestion', 'bloom_breakdown']]]);
        $this->assertEquals('Basic Arithmetic', $response->json('improvement_roadmap.0.topic'));
        $this->assertStringContainsStringIgnoringCase('re-watch foundational lectures', $response->json('improvement_roadmap.0.suggestion'));
    }

    public function test_learning_gaps_are_scoped_to_the_authenticated_candidate_only(): void
    {
        [, $tokenA] = $this->makeUserWithToken('candidate', 'a@test.local');
        [, $tokenB] = $this->makeUserWithToken('candidate', 'b@test.local');

        $response = $this->getJson('/api/learning-gaps', $this->authHeaders($tokenB));
        $response->assertStatus(200)->assertJson(['learning_gaps' => []]);
    }
}
