<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\ExamSession;
use App\Models\Question;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Tests\Concerns\CreatesTestUsers;
use Tests\TestCase;

/**
 * Phase E (SRS FR-ED-02): the batch answer-sync endpoint used to submit
 * locally-queued answers once connectivity returns. saveAnswer() itself
 * is untouched and stays covered by ExamDeliveryGradingTest — this file
 * covers only the new sync endpoint.
 */
class OfflineAnswerSyncTest extends TestCase
{
    use RefreshDatabase;
    use CreatesTestUsers;

    private function makeExamWithQuestions(): array
    {
        [$examiner] = $this->makeUserWithToken('examiner');

        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Sync Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0.25,
            'status' => 'published',
        ]);

        $mcq = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => '2 + 2 = ?',
            'question_type' => 'mcq',
            'marks' => 5,
            'difficulty' => 'easy',
            'bloom_taxonomy' => 'remember',
            'options' => ['3', '4', '5'],
            'correct_answer' => '4',
            'is_ai_generated' => false,
            'review_status' => 'approved',
        ]);

        $shortAnswer = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'What does GPU stand for?',
            'question_type' => 'short_answer',
            'marks' => 5,
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'understand',
            'options' => null,
            'correct_answer' => 'Graphics Processing Unit',
            'is_ai_generated' => false,
            'review_status' => 'approved',
        ]);

        return [$exam, $mcq, $shortAnswer];
    }

    private function beginCandidateSession(int $examId, string $candidateHeadersToken): int
    {
        return $this->postJson(
            "/api/exams/{$examId}/session",
            [],
            $this->authHeaders($candidateHeadersToken),
        )->json('session.id');
    }

    public function test_authenticated_candidate_can_sync_a_valid_queued_answer(): void
    {
        [$exam, $mcq] = $this->makeExamWithQuestions();
        [, $candidateToken] = $this->makeUserWithToken('candidate');
        $sessionId = $this->beginCandidateSession($exam->id, $candidateToken);

        $response = $this->postJson(
            "/api/exam-sessions/{$sessionId}/answers/sync",
            ['answers' => [['question_id' => $mcq->id, 'selected_option' => '4']]],
            $this->authHeaders($candidateToken),
        );

        $response->assertStatus(200)->assertJson([
            'results' => [
                ['question_id' => $mcq->id, 'status' => 'synced'],
            ],
        ]);

        $this->assertDatabaseHas('answers', [
            'exam_session_id' => $sessionId,
            'question_id' => $mcq->id,
            'selected_option' => '4',
        ]);
    }

    public function test_unauthenticated_request_is_rejected(): void
    {
        [$exam, $mcq] = $this->makeExamWithQuestions();
        [, $candidateToken] = $this->makeUserWithToken('candidate');
        $sessionId = $this->beginCandidateSession($exam->id, $candidateToken);

        // Force the Sanctum guard to forget its cached resolution from
        // beginCandidateSession()'s own request above (see
        // CreatesTestUsers::authHeaders' doc comment) — otherwise this
        // request, despite carrying no Authorization header at all,
        // could still resolve as whichever user the guard last resolved.
        Auth::forgetGuards();

        $response = $this->postJson(
            "/api/exam-sessions/{$sessionId}/answers/sync",
            ['answers' => [['question_id' => $mcq->id, 'selected_option' => '4']]],
        );

        $response->assertStatus(401);
    }

    public function test_a_candidate_cannot_sync_another_candidates_session(): void
    {
        [$exam, $mcq] = $this->makeExamWithQuestions();
        [, $ownerToken] = $this->makeUserWithToken('candidate', 'owner@test.local');
        [, $otherToken] = $this->makeUserWithToken('candidate', 'other@test.local');
        $sessionId = $this->beginCandidateSession($exam->id, $ownerToken);

        $response = $this->postJson(
            "/api/exam-sessions/{$sessionId}/answers/sync",
            ['answers' => [['question_id' => $mcq->id, 'selected_option' => '4']]],
            $this->authHeaders($otherToken),
        );

        $response->assertStatus(403);
        $this->assertDatabaseMissing('answers', [
            'exam_session_id' => $sessionId,
            'question_id' => $mcq->id,
        ]);
    }

    public function test_multiple_queued_answers_are_synced_in_one_request(): void
    {
        [$exam, $mcq, $shortAnswer] = $this->makeExamWithQuestions();
        [, $candidateToken] = $this->makeUserWithToken('candidate');
        $sessionId = $this->beginCandidateSession($exam->id, $candidateToken);

        $response = $this->postJson(
            "/api/exam-sessions/{$sessionId}/answers/sync",
            ['answers' => [
                ['question_id' => $mcq->id, 'selected_option' => '4'],
                ['question_id' => $shortAnswer->id, 'selected_option' => 'Graphics Processing Unit'],
            ]],
            $this->authHeaders($candidateToken),
        );

        $response->assertStatus(200);
        $results = collect($response->json('results'));
        $this->assertTrue($results->every(fn ($r) => $r['status'] === 'synced'));
        $this->assertDatabaseCount('answers', 2);
    }

    public function test_duplicate_synchronization_does_not_create_duplicate_answer_rows(): void
    {
        [$exam, $mcq] = $this->makeExamWithQuestions();
        [, $candidateToken] = $this->makeUserWithToken('candidate');
        $sessionId = $this->beginCandidateSession($exam->id, $candidateToken);
        $headers = $this->authHeaders($candidateToken);

        $payload = ['answers' => [['question_id' => $mcq->id, 'selected_option' => '4']]];

        $this->postJson("/api/exam-sessions/{$sessionId}/answers/sync", $payload, $headers)
            ->assertStatus(200);
        // Same item submitted again — simulates a retried/duplicate sync
        // invocation (app restart, timeout-after-success, etc.).
        $this->postJson("/api/exam-sessions/{$sessionId}/answers/sync", $payload, $headers)
            ->assertStatus(200);

        $this->assertDatabaseCount('answers', 1);
        $this->assertDatabaseHas('answers', [
            'exam_session_id' => $sessionId,
            'question_id' => $mcq->id,
            'selected_option' => '4',
        ]);
    }

    public function test_a_malformed_batch_item_is_rejected_safely_without_aborting_the_rest(): void
    {
        [$exam, $mcq, $shortAnswer] = $this->makeExamWithQuestions();
        [, $candidateToken] = $this->makeUserWithToken('candidate');
        $sessionId = $this->beginCandidateSession($exam->id, $candidateToken);

        $response = $this->postJson(
            "/api/exam-sessions/{$sessionId}/answers/sync",
            ['answers' => [
                ['question_id' => $mcq->id, 'selected_option' => '4'], // valid
                ['question_id' => 999999, 'selected_option' => 'X'], // question doesn't exist
                ['question_id' => $shortAnswer->id, 'selected_option' => 'Graphics Processing Unit'], // valid
            ]],
            $this->authHeaders($candidateToken),
        );

        $response->assertStatus(200);
        $results = collect($response->json('results'));

        $this->assertSame('synced', $results->firstWhere('question_id', $mcq->id)['status']);
        $this->assertSame('synced', $results->firstWhere('question_id', $shortAnswer->id)['status']);

        $missing = $results->firstWhere('question_id', 999999);
        $this->assertSame('conflict', $missing['status']);
        $this->assertSame('VALIDATION_FAILED', $missing['code']);
        $this->assertArrayHasKey('message', $missing);

        // The whole request did not abort — both valid items were saved
        // despite the malformed one in between them.
        $this->assertDatabaseCount('answers', 2);
    }

    public function test_a_session_that_is_no_longer_syncable_reports_a_conflict_without_writing_answers(): void
    {
        [$exam, $mcq] = $this->makeExamWithQuestions();
        [, $candidateToken] = $this->makeUserWithToken('candidate');
        $sessionId = $this->beginCandidateSession($exam->id, $candidateToken);

        // Simulate the session already having been submitted.
        ExamSession::whereKey($sessionId)->update(['status' => 'submitted']);

        $response = $this->postJson(
            "/api/exam-sessions/{$sessionId}/answers/sync",
            ['answers' => [['question_id' => $mcq->id, 'selected_option' => '4']]],
            $this->authHeaders($candidateToken),
        );

        $response->assertStatus(200)->assertJson([
            'results' => [
                ['question_id' => $mcq->id, 'status' => 'conflict', 'code' => 'CONFLICT_SESSION_CLOSED'],
            ],
        ]);
        $this->assertDatabaseMissing('answers', [
            'exam_session_id' => $sessionId,
            'question_id' => $mcq->id,
        ]);
    }

    public function test_a_stale_queued_answer_does_not_overwrite_a_newer_server_answer(): void
    {
        [$exam, $mcq] = $this->makeExamWithQuestions();
        [, $candidateToken] = $this->makeUserWithToken('candidate');
        $headers = $this->authHeaders($candidateToken);
        $sessionId = $this->beginCandidateSession($exam->id, $candidateToken);

        // The candidate answers online (fresh, current) first.
        $this->putJson(
            "/api/exam-sessions/{$sessionId}/answers/{$mcq->id}",
            ['selected_option' => '4'],
            $headers,
        )->assertStatus(200);

        // A stale offline-queued edit (timestamped before the online
        // answer above) now attempts to sync — it must not win.
        $response = $this->postJson(
            "/api/exam-sessions/{$sessionId}/answers/sync",
            ['answers' => [[
                'question_id' => $mcq->id,
                'selected_option' => '3', // the stale, would-be-wrong value
                'client_updated_at' => now()->subMinutes(10)->toIso8601String(),
            ]]],
            $headers,
        );

        $response->assertStatus(200)->assertJson([
            'results' => [
                ['question_id' => $mcq->id, 'status' => 'conflict', 'code' => 'SERVER_VERSION_AHEAD'],
            ],
        ]);

        // The server's newer, correct answer is untouched.
        $this->assertDatabaseHas('answers', [
            'exam_session_id' => $sessionId,
            'question_id' => $mcq->id,
            'selected_option' => '4',
        ]);
    }

    public function test_a_newer_queued_answer_correctly_overwrites_an_older_server_answer(): void
    {
        [$exam, $mcq] = $this->makeExamWithQuestions();
        [, $candidateToken] = $this->makeUserWithToken('candidate');
        $headers = $this->authHeaders($candidateToken);
        $sessionId = $this->beginCandidateSession($exam->id, $candidateToken);

        // An older answer already exists (e.g. synced from a previous
        // batch, or saved online earlier).
        $this->putJson(
            "/api/exam-sessions/{$sessionId}/answers/{$mcq->id}",
            ['selected_option' => '3'],
            $headers,
        )->assertStatus(200);

        // The candidate then changed their mind offline, and this queued
        // edit is timestamped after the existing server answer — it must
        // win, exactly like a normal sync.
        $response = $this->postJson(
            "/api/exam-sessions/{$sessionId}/answers/sync",
            ['answers' => [[
                'question_id' => $mcq->id,
                'selected_option' => '4',
                'client_updated_at' => now()->addMinutes(10)->toIso8601String(),
            ]]],
            $headers,
        );

        $response->assertStatus(200)->assertJson([
            'results' => [
                ['question_id' => $mcq->id, 'status' => 'synced'],
            ],
        ]);
        $this->assertDatabaseHas('answers', [
            'exam_session_id' => $sessionId,
            'question_id' => $mcq->id,
            'selected_option' => '4',
        ]);
    }

    public function test_synced_answers_grade_correctly_on_submit_exactly_like_a_normal_online_save(): void
    {
        [$exam, $mcq, $shortAnswer] = $this->makeExamWithQuestions();
        [, $candidateToken] = $this->makeUserWithToken('candidate');
        $headers = $this->authHeaders($candidateToken);
        $sessionId = $this->beginCandidateSession($exam->id, $candidateToken);

        $this->postJson(
            "/api/exam-sessions/{$sessionId}/answers/sync",
            ['answers' => [
                ['question_id' => $mcq->id, 'selected_option' => '4'], // correct
                ['question_id' => $shortAnswer->id, 'selected_option' => 'wrong answer'], // incorrect
            ]],
            $headers,
        )->assertStatus(200);

        $submit = $this->postJson("/api/exam-sessions/{$sessionId}/submit", [], $headers);

        $submit->assertStatus(200)->assertJson([
            'result' => [
                // 5 (correct mcq) + (short_answer unmatched -> manual review @ 0 marks) = 5
                'total_score' => 5,
                'max_score' => 10.0,
                'status' => 'pending_manual_review',
            ],
        ]);
    }
}
