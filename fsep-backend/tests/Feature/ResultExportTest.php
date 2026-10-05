<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\Question;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesTestUsers;
use Tests\TestCase;

/**
 * PDF/Excel export — same ownership rule as GET /results/{session}, same
 * underlying Result data (no recalculation).
 */
class ResultExportTest extends TestCase
{
    use RefreshDatabase;
    use CreatesTestUsers;

    private function makeGradedSession(): array
    {
        [$examiner] = $this->makeUserWithToken('examiner');
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Export Test Exam',
            'course_code' => 'CS101',
            'duration_minutes' => 60,
            'total_marks' => 5,
            'negative_marking_weight' => 0,
            'status' => 'draft',
        ]);
        $question = Question::create([
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

        [, $candidateToken] = $this->makeUserWithToken('candidate');
        $headers = $this->authHeaders($candidateToken);
        $sessionId = $this->postJson("/api/exams/{$exam->id}/session", [], $headers)
            ->json('session.id');
        $this->putJson(
            "/api/exam-sessions/{$sessionId}/answers/{$question->id}",
            ['selected_option' => '4'],
            $headers,
        );
        $this->postJson("/api/exam-sessions/{$sessionId}/submit", [], $headers);

        return [$sessionId, $headers];
    }

    public function test_candidate_can_export_their_own_result_as_pdf_and_excel(): void
    {
        [$sessionId, $headers] = $this->makeGradedSession();

        $pdf = $this->get("/api/results/{$sessionId}/pdf", $headers);
        $pdf->assertStatus(200);
        $pdfContent = $pdf->getContent();
        $this->assertStringContainsString('application/pdf', $pdf->headers->get('Content-Type'));
        $this->assertGreaterThan(500, strlen($pdfContent));
        $this->assertStringStartsWith('%PDF', $pdfContent);

        // The Excel endpoint uses Response::streamDownload() (a
        // StreamedResponse) — Symfony's plain getContent() never
        // captures streamed output by design; streamedContent() is
        // Laravel's dedicated test helper that actually invokes the
        // stream callback and buffers it.
        $excel = $this->get("/api/results/{$sessionId}/excel", $headers);
        $excel->assertStatus(200);
        $excelContent = $excel->streamedContent();
        $this->assertStringContainsString('spreadsheetml', $excel->headers->get('Content-Type'));
        $this->assertGreaterThan(500, strlen($excelContent));
        $this->assertStringStartsWith("PK\x03\x04", $excelContent);
    }

    public function test_a_candidate_cannot_export_another_candidates_result(): void
    {
        [$sessionId] = $this->makeGradedSession();
        [, $otherToken] = $this->makeUserWithToken('candidate', 'notowner@test.local');

        $this->get("/api/results/{$sessionId}/pdf", $this->authHeaders($otherToken))
            ->assertStatus(403);
        $this->get("/api/results/{$sessionId}/excel", $this->authHeaders($otherToken))
            ->assertStatus(403);
    }

    public function test_unauthenticated_export_request_is_rejected(): void
    {
        [$sessionId] = $this->makeGradedSession();

        // makeGradedSession() authenticated as a candidate above; the
        // Sanctum guard caches that resolution for the test's lifetime
        // (see CreatesTestUsers::authHeaders doc) — forget it explicitly
        // so this request is genuinely unauthenticated, not accidentally
        // still carrying the previous candidate's resolved identity.
        \Illuminate\Support\Facades\Auth::forgetGuards();

        $this->getJson("/api/results/{$sessionId}/pdf")->assertStatus(401);
    }
}
