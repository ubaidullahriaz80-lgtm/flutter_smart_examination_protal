<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\Question;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesTestUsers;
use Tests\TestCase;

/**
 * Full candidate exam lifecycle: start -> answer -> submit -> auto-grade
 * (+ negative marking) -> manual grade -> recalculated result. This is
 * the single most SRS-critical flow in the application (FR-ED, Grading,
 * Results) so it gets the deepest coverage.
 */
class ExamDeliveryGradingTest extends TestCase
{
    use RefreshDatabase;
    use CreatesTestUsers;

    private function makeExamWithQuestions(): array
    {
        [$examiner] = $this->makeUserWithToken('examiner');

        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Grading Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 15,
            'negative_marking_weight' => 0.25,
            'status' => 'draft',
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

        $essay = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'Explain recursion.',
            'question_type' => 'essay',
            'marks' => 10,
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'understand',
            'options' => null,
            'correct_answer' => null,
            'is_ai_generated' => false,
            'review_status' => 'approved',
        ]);

        return [$exam, $mcq, $essay];
    }

    public function test_full_lifecycle_correct_mcq_and_essay_pending_review(): void
    {
        [$exam, $mcq, $essay] = $this->makeExamWithQuestions();
        [, $candidateToken] = $this->makeUserWithToken('candidate');
        $candidateHeaders = $this->authHeaders($candidateToken);

        $start = $this->postJson("/api/exams/{$exam->id}/session", [], $candidateHeaders);
        $start->assertStatus(200);
        $sessionId = $start->json('session.id');

        $this->putJson(
            "/api/exam-sessions/{$sessionId}/answers/{$mcq->id}",
            ['selected_option' => '4'],
            $candidateHeaders,
        )->assertStatus(200);

        $this->putJson(
            "/api/exam-sessions/{$sessionId}/answers/{$essay->id}",
            ['selected_option' => 'Recursion is a function calling itself.'],
            $candidateHeaders,
        )->assertStatus(200);

        $submit = $this->postJson("/api/exam-sessions/{$sessionId}/submit", [], $candidateHeaders);
        $submit->assertStatus(200)
            ->assertJson([
                'result' => [
                    'total_score' => 5.0,
                    'max_score' => 15.0,
                    'status' => 'pending_manual_review',
                ],
            ]);

        // Essay must never be silently marked correct/incorrect or scored.
        $questionResults = collect($submit->json('result.question_results'));
        $essayResult = $questionResults->firstWhere('question_id', $essay->id);
        $this->assertNull($essayResult['is_correct']);
        $this->assertNull($essayResult['obtained_marks']);

        [, $examinerToken] = $this->makeUserWithToken('examiner');
        $graded = $this->putJson(
            "/api/exam-sessions/{$sessionId}/answers/{$essay->id}/manual-grade",
            ['obtained_marks' => 8],
            $this->authHeaders($examinerToken),
        );

        $graded->assertStatus(200)->assertJson([
            'result' => ['total_score' => 13.0, 'max_score' => 15.0, 'status' => 'graded'],
        ]);
    }

    public function test_incorrect_mcq_answer_applies_negative_marking(): void
    {
        [$exam, $mcq] = $this->makeExamWithQuestions();
        [, $candidateToken] = $this->makeUserWithToken('candidate');
        $headers = $this->authHeaders($candidateToken);

        $sessionId = $this->postJson("/api/exams/{$exam->id}/session", [], $headers)
            ->json('session.id');

        $this->putJson(
            "/api/exam-sessions/{$sessionId}/answers/{$mcq->id}",
            ['selected_option' => '3'], // wrong
            $headers,
        )->assertStatus(200);

        $submit = $this->postJson("/api/exam-sessions/{$sessionId}/submit", [], $headers);

        // -(5 marks * 0.25 negative_marking_weight) = -1.25
        $this->assertEquals(-1.25, $submit->json('result.question_results.0.obtained_marks'));
    }

    /**
     * SRS approval gate: an exam with 2 approved, 1 pending, and 1
     * rejected question must deliver only the 2 approved questions to a
     * candidate — via exam loading, via direct answer-submission attempts
     * against the hidden questions' ids, and in the final grading/result.
     */
    public function test_pending_and_rejected_questions_are_never_delivered_or_gradable(): void
    {
        [$examiner] = $this->makeUserWithToken('examiner');

        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Approval Gate Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 20,
            'negative_marking_weight' => 0.25,
            'status' => 'published',
        ]);

        $approved1 = Question::create([
            'exam_id' => $exam->id, 'created_by' => $examiner->id,
            'question_text' => 'Approved Q1', 'question_type' => 'mcq', 'marks' => 5,
            'difficulty' => 'easy', 'bloom_taxonomy' => 'remember',
            'options' => ['A', 'B'], 'correct_answer' => 'A',
            'is_ai_generated' => false, 'review_status' => 'approved',
        ]);
        $approved2 = Question::create([
            'exam_id' => $exam->id, 'created_by' => $examiner->id,
            'question_text' => 'Approved Q2', 'question_type' => 'true_false', 'marks' => 5,
            'difficulty' => 'easy', 'bloom_taxonomy' => 'remember',
            'options' => null, 'correct_answer' => 'True',
            'is_ai_generated' => false, 'review_status' => 'approved',
        ]);
        $pending = Question::create([
            'exam_id' => $exam->id, 'created_by' => $examiner->id,
            'question_text' => 'Pending Q', 'question_type' => 'mcq', 'marks' => 5,
            'difficulty' => 'easy', 'bloom_taxonomy' => 'remember',
            'options' => ['A', 'B'], 'correct_answer' => 'A',
            'is_ai_generated' => true, 'review_status' => 'pending',
        ]);
        $rejected = Question::create([
            'exam_id' => $exam->id, 'created_by' => $examiner->id,
            'question_text' => 'Rejected Q', 'question_type' => 'mcq', 'marks' => 5,
            'difficulty' => 'easy', 'bloom_taxonomy' => 'remember',
            'options' => ['A', 'B'], 'correct_answer' => 'A',
            'is_ai_generated' => true, 'review_status' => 'rejected',
        ]);

        [, $candidateToken] = $this->makeUserWithToken('candidate');
        $candidateHeaders = $this->authHeaders($candidateToken);

        // 1. Exam detail must expose only the 2 approved questions.
        $detail = $this->getJson("/api/exams/{$exam->id}", $candidateHeaders);
        $detail->assertStatus(200);
        $deliveredIds = collect($detail->json('exam.questions'))->pluck('id');
        $this->assertCount(2, $deliveredIds);
        $this->assertTrue($deliveredIds->contains($approved1->id));
        $this->assertTrue($deliveredIds->contains($approved2->id));
        $this->assertFalse($deliveredIds->contains($pending->id));
        $this->assertFalse($deliveredIds->contains($rejected->id));

        // 2. Exam list must apply the same filter.
        $list = $this->getJson('/api/exams', $candidateHeaders);
        $listedExam = collect($list->json('exams'))->firstWhere('id', $exam->id);
        $listedIds = collect($listedExam['questions'])->pluck('id');
        $this->assertCount(2, $listedIds);

        // 3. Examiner must still see all 4, unfiltered.
        $examinerHeaders = $this->authHeaders($this->makeUserWithToken('examiner')[1]);
        $examinerDetail = $this->getJson("/api/exams/{$exam->id}", $examinerHeaders);
        $this->assertCount(4, $examinerDetail->json('exam.questions'));

        // 4. Direct protection: answering the pending/rejected question's
        // id directly (guessed or otherwise) must be rejected, even
        // though the candidate never saw it via exam loading.
        //
        // Re-derive fresh candidate headers here: the examiner check just
        // above forces the Sanctum guard to re-resolve as the examiner
        // (see CreatesTestUsers::authHeaders doc comment) — reusing the
        // earlier $candidateHeaders value without calling authHeaders()
        // again would authenticate this request as that examiner instead.
        $candidateHeaders = $this->authHeaders($candidateToken);

        $sessionId = $this->postJson("/api/exams/{$exam->id}/session", [], $candidateHeaders)
            ->json('session.id');

        $this->putJson(
            "/api/exam-sessions/{$sessionId}/answers/{$pending->id}",
            ['selected_option' => 'A'],
            $candidateHeaders,
        )->assertStatus(422);

        $this->putJson(
            "/api/exam-sessions/{$sessionId}/answers/{$rejected->id}",
            ['selected_option' => 'A'],
            $candidateHeaders,
        )->assertStatus(422);

        // 5. The 2 approved questions still answer/grade exactly as
        // before; max_score reflects only the 2 delivered questions
        // (10), not all 4 on the exam (20).
        $this->putJson(
            "/api/exam-sessions/{$sessionId}/answers/{$approved1->id}",
            ['selected_option' => 'A'],
            $candidateHeaders,
        )->assertStatus(200);

        $this->putJson(
            "/api/exam-sessions/{$sessionId}/answers/{$approved2->id}",
            ['selected_option' => 'True'],
            $candidateHeaders,
        )->assertStatus(200);

        $submit = $this->postJson("/api/exam-sessions/{$sessionId}/submit", [], $candidateHeaders);
        $submit->assertStatus(200)->assertJson([
            'result' => [
                'total_score' => 10.0,
                'max_score' => 10.0,
                'status' => 'graded',
            ],
        ]);
        $this->assertCount(2, $submit->json('result.question_results'));
    }

    public function test_a_candidate_cannot_access_another_candidates_session(): void
    {
        [$exam] = $this->makeExamWithQuestions();
        [, $ownerToken] = $this->makeUserWithToken('candidate', 'owner@test.local');
        [, $otherToken] = $this->makeUserWithToken('candidate', 'other@test.local');

        $sessionId = $this->postJson(
            "/api/exams/{$exam->id}/session",
            [],
            $this->authHeaders($ownerToken),
        )->json('session.id');

        // Ownership is checked before existence, so a non-owner is
        // rejected with 403 regardless of whether a Result exists yet.
        $this->getJson(
            "/api/results/{$sessionId}",
            $this->authHeaders($otherToken),
        )->assertStatus(403);

        $this->postJson(
            "/api/exam-sessions/{$sessionId}/submit",
            [],
            $this->authHeaders($otherToken),
        )->assertStatus(403);
    }
}
