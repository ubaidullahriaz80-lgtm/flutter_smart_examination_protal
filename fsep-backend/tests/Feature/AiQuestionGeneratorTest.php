<?php

namespace Tests\Feature;

use App\Models\Exam;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\Concerns\CreatesTestUsers;
use Tests\TestCase;

/**
 * Novelty #2 — AI Question Generator. The real Gemini call is faked here
 * (Http::fake) — this is standard practice for an automated test suite
 * that must run offline/in CI without spending real API quota; the real
 * live Gemini integration itself continues to be verified by hand
 * against the actual API, exactly as done throughout this project's
 * development. This test verifies FSEP's own wiring around that call:
 * validation, distribution across exams/types, and that
 * is_ai_generated/review_status are preserved through save — not
 * Gemini's own behavior.
 */
class AiQuestionGeneratorTest extends TestCase
{
    use RefreshDatabase;
    use CreatesTestUsers;

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.gemini.key' => 'fake-test-key', 'services.gemini.model' => 'gemini-test']);
    }

    private function fakeGeminiResponse(int $count = 1): void
    {
        $questions = [];
        for ($i = 0; $i < $count; $i++) {
            $questions[] = [
                'question_text' => "Fake question {$i}?",
                'marks' => 5,
                'difficulty' => 'easy',
                'bloom_taxonomy' => 'remember',
                'topic_tag' => 'Fake Topic',
                'options' => ['A', 'B', 'C', 'D'],
                'correct_answer' => 'A',
            ];
        }

        Http::fake([
            'generativelanguage.googleapis.com/*' => Http::response([
                'candidates' => [
                    ['content' => ['parts' => [['text' => json_encode(['questions' => $questions])]]]],
                ],
            ]),
        ]);
    }

    public function test_generated_questions_preserve_ai_flag_and_pending_review_after_save(): void
    {
        [$examiner, $token] = $this->makeUserWithToken('examiner');
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'AI Gen Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 5,
            'negative_marking_weight' => 0,
            'status' => 'draft',
        ]);
        $headers = $this->authHeaders($token);
        $this->fakeGeminiResponse(1);

        $generate = $this->postJson('/api/questions/generate', [
            'exam_id' => $exam->id,
            'topic' => 'Test Topic',
            'question_type' => 'mcq',
            'difficulty' => 'easy',
            'bloom_taxonomy' => 'remember',
            'count' => 1,
            'marks' => 5,
        ], $headers);

        $generate->assertStatus(200)
            ->assertJson(['questions' => [['is_ai_generated' => true, 'exam_id' => $exam->id]]]);

        $draft = $generate->json('questions.0');
        $save = $this->postJson('/api/questions', array_merge($draft, ['exam_id' => $exam->id]), $headers);

        $save->assertStatus(201)->assertJson([
            'question' => ['is_ai_generated' => true, 'review_status' => 'pending'],
        ]);
    }

    public function test_multiple_exams_and_types_are_distributed_evenly(): void
    {
        [$examiner, $token] = $this->makeUserWithToken('examiner');
        $examA = Exam::create([
            'created_by' => $examiner->id, 'title' => 'Exam A',
            'duration_minutes' => 60, 'total_marks' => 5, 'negative_marking_weight' => 0, 'status' => 'draft',
        ]);
        $examB = Exam::create([
            'created_by' => $examiner->id, 'title' => 'Exam B',
            'duration_minutes' => 60, 'total_marks' => 5, 'negative_marking_weight' => 0, 'status' => 'draft',
        ]);
        // Only one question_type is selected, so the controller makes a
        // single Gemini call for all 4 requested questions — the fake
        // must return all 4, not split per exam (distribution across
        // exams happens after generation, purely in FSEP's own code).
        $this->fakeGeminiResponse(4);

        $response = $this->postJson('/api/questions/generate', [
            'exam_ids' => [$examA->id, $examB->id],
            'topic' => 'Test Topic',
            'question_types' => ['mcq'],
            'difficulty' => 'easy',
            'bloom_taxonomy' => 'remember',
            'count' => 4,
            'marks' => 5,
        ], $this->authHeaders($token));

        $response->assertStatus(200);
        $examIds = collect($response->json('questions'))->pluck('exam_id');
        $this->assertSame(2, $examIds->filter(fn ($id) => $id === $examA->id)->count());
        $this->assertSame(2, $examIds->filter(fn ($id) => $id === $examB->id)->count());
    }

    public function test_duplicate_exam_ids_are_rejected(): void
    {
        [$examiner, $token] = $this->makeUserWithToken('examiner');
        $exam = Exam::create([
            'created_by' => $examiner->id, 'title' => 'Dup Exam',
            'duration_minutes' => 60, 'total_marks' => 5, 'negative_marking_weight' => 0, 'status' => 'draft',
        ]);

        $this->postJson('/api/questions/generate', [
            'exam_ids' => [$exam->id, $exam->id],
            'topic' => 'x', 'question_types' => ['mcq'],
            'difficulty' => 'easy', 'bloom_taxonomy' => 'remember',
            'count' => 1, 'marks' => 5,
        ], $this->authHeaders($token))->assertStatus(422);
    }

    public function test_empty_exam_and_type_selections_are_rejected(): void
    {
        [, $token] = $this->makeUserWithToken('examiner');
        $headers = $this->authHeaders($token);

        $this->postJson('/api/questions/generate', [
            'exam_ids' => [], 'topic' => 'x', 'question_types' => ['mcq'],
            'difficulty' => 'easy', 'bloom_taxonomy' => 'remember', 'count' => 1, 'marks' => 5,
        ], $headers)->assertStatus(422);

        [$examiner2] = $this->makeUserWithToken('examiner', 'e2@test.local');
        $exam = Exam::create([
            'created_by' => $examiner2->id, 'title' => 'E',
            'duration_minutes' => 60, 'total_marks' => 5, 'negative_marking_weight' => 0, 'status' => 'draft',
        ]);
        $this->postJson('/api/questions/generate', [
            'exam_ids' => [$exam->id], 'topic' => 'x', 'question_types' => [],
            'difficulty' => 'easy', 'bloom_taxonomy' => 'remember', 'count' => 1, 'marks' => 5,
        ], $headers)->assertStatus(422);
    }

    public function test_candidate_cannot_generate_questions(): void
    {
        [, $token] = $this->makeUserWithToken('candidate');

        $this->postJson('/api/questions/generate', [
            'exam_id' => 1, 'topic' => 'x', 'question_type' => 'mcq',
            'difficulty' => 'easy', 'bloom_taxonomy' => 'remember', 'count' => 1, 'marks' => 5,
        ], $this->authHeaders($token))->assertStatus(403);
    }
}
