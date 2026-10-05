<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\ExamSession;
use App\Models\Question;
use App\Models\User;
use App\Services\FcmService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Mockery;
use Mockery\MockInterface;
use Tests\TestCase;

class ExamEvaluationNotificationFrPn02Test extends TestCase
{
    use RefreshDatabase;

    public function test_submit_triggers_notification_with_score_and_report_link(): void
    {
        $candidate = User::factory()->create(['role' => 'candidate']);
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'Biology', 'duration_minutes' => 60, 'total_marks' => 10]);

        $question = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'Q',
            'question_type' => 'mcq',
            'marks' => 10,
            'options' => ['A', 'B'],
            'correct_answer' => 'A',
            'review_status' => 'approved',
        ]);

        $session = ExamSession::create(['exam_id' => $exam->id, 'candidate_id' => $candidate->id, 'status' => 'in_progress', 'started_at' => now(), 'expires_at' => now()->addHour()]);
        $session->answers()->create(['question_id' => $question->id, 'selected_option' => 'A']);

        // Mock FcmService
        $this->instance(
            FcmService::class,
            Mockery::mock(FcmService::class, function (MockInterface $mock) use ($candidate, $session) {
                $mock->shouldReceive('sendToUser')
                    ->once()
                    ->with(
                        Mockery::on(fn($u) => $u->id === $candidate->id),
                        Mockery::pattern('/Evaluation Published/'),
                        Mockery::pattern('/Final Score: 10 \/ 10/'),
                        Mockery::on(fn($d) => $d['type'] === 'exam_result' && $d['session_id'] == (string)$session->id)
                    );
            })
        );

        $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/submit")
            ->assertStatus(200);

        $this->assertDatabaseHas('learning_gap_reports', ['exam_session_id' => $session->id]);
    }

    public function test_manual_grading_triggers_notification_with_updated_score(): void
    {
        $candidate = User::factory()->create(['role' => 'candidate']);
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'Math', 'duration_minutes' => 60, 'total_marks' => 10]);

        $question = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'Solve 2+2',
            'question_type' => 'essay',
            'marks' => 10,
            'review_status' => 'approved',
        ]);

        $session = ExamSession::create(['exam_id' => $exam->id, 'candidate_id' => $candidate->id, 'status' => 'submitted', 'started_at' => now(), 'submitted_at' => now()]);
        $session->answers()->create(['question_id' => $question->id, 'selected_option' => '4', 'grading_status' => 'pending_manual_review']);

        // Mock FcmService
        $this->instance(
            FcmService::class,
            Mockery::mock(FcmService::class, function (MockInterface $mock) use ($candidate, $session) {
                $mock->shouldReceive('sendToUser')
                    ->once()
                    ->with(
                        Mockery::on(fn($u) => $u->id === $candidate->id),
                        Mockery::pattern('/Evaluation Updated/'),
                        Mockery::pattern('/Final Score: 8 \/ 10/'),
                        Mockery::on(fn($d) => $d['type'] === 'exam_result' && $d['session_id'] == (string)$session->id)
                    );
            })
        );

        $this->actingAs($examiner)->putJson("/api/exam-sessions/{$session->id}/answers/{$question->id}/manual-grade", [
            'obtained_marks' => 8
        ])->assertStatus(200);
    }
}
