<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\ExamSession;
use App\Models\LearningGapReport;
use App\Models\Question;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesTestUsers;
use Tests\TestCase;

class LearningGapPersistenceTest extends TestCase
{
    use RefreshDatabase;
    use CreatesTestUsers;

    public function test_report_is_persisted_on_exam_submission(): void
    {
        [$examiner] = $this->makeUserWithToken('examiner');
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
            'status' => 'published',
        ]);

        $q = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'Q1',
            'question_type' => 'mcq',
            'marks' => 10,
            'topic_tag' => 'Logic',
            'review_status' => 'approved',
            'options' => ['A', 'B'],
            'correct_answer' => 'A'
        ]);

        [, $token] = $this->makeUserWithToken('candidate');
        $headers = $this->authHeaders($token);

        $sessionResponse = $this->postJson("/api/exams/{$exam->id}/session", [], $headers);
        $sessionId = $sessionResponse->json('session.id');

        $this->putJson("/api/exam-sessions/{$sessionId}/answers/{$q->id}", ['selected_option' => 'A'], $headers);

        $this->postJson("/api/exam-sessions/{$sessionId}/submit", [], $headers)->assertStatus(200);

        $this->assertDatabaseHas('learning_gap_reports', [
            'exam_session_id' => $sessionId,
            'exam_id' => $exam->id,
        ]);

        $report = LearningGapReport::where('exam_session_id', $sessionId)->first();
        $this->assertEquals(1, $report->questions_attempted);
        $this->assertNotEmpty($report->all_topics);
    }

    public function test_candidate_can_retrieve_their_own_persisted_report(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $candidate = User::factory()->create(['role' => 'candidate']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'T1',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
        ]);
        $session = ExamSession::create([
            'exam_id' => $exam->id,
            'candidate_id' => $candidate->id,
            'status' => 'submitted',
            'started_at' => now(),
            'expires_at' => now()->addHour()
        ]);

        $report = LearningGapReport::create([
            'exam_session_id' => $session->id,
            'candidate_id' => $candidate->id,
            'exam_id' => $exam->id,
            'learning_gaps' => [],
            'all_topics' => [['topic' => 'Test', 'percentage' => 100]],
            'bloom_profile' => [],
            'difficulty_profile' => [],
            'improvement_roadmap' => [],
            'topics_analyzed' => 1,
            'questions_attempted' => 1,
        ]);

        $response = $this->actingAs($candidate)->getJson("/api/learning/report/{$session->id}");

        $response->assertStatus(200);
        $this->assertEquals($report->id, $response->json('id'));
    }

    public function test_candidate_cannot_retrieve_another_candidates_report(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $c1 = User::factory()->create(['role' => 'candidate']);
        $c2 = User::factory()->create(['role' => 'candidate']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'T2',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
        ]);
        $session = ExamSession::create([
            'exam_id' => $exam->id,
            'candidate_id' => $c1->id,
            'status' => 'submitted',
            'started_at' => now(),
            'expires_at' => now()->addHour()
        ]);

        $this->actingAs($c2)->getJson("/api/learning/report/{$session->id}")->assertStatus(403);
    }

    public function test_history_endpoint_returns_all_reports(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $candidate = User::factory()->create(['role' => 'candidate']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'H1',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
        ]);

        $s1 = ExamSession::create(['exam_id' => $exam->id, 'candidate_id' => $candidate->id, 'status' => 'submitted', 'started_at' => now(), 'expires_at' => now()->addHour()]);

        LearningGapReport::create([
            'exam_session_id' => $s1->id, 'candidate_id' => $candidate->id, 'exam_id' => $exam->id,
            'learning_gaps' => [], 'all_topics' => [], 'bloom_profile' => [], 'difficulty_profile' => [],
            'improvement_roadmap' => [], 'topics_analyzed' => 1, 'questions_attempted' => 1,
        ]);

        $response = $this->actingAs($candidate)->getJson('/api/learning/history');

        $response->assertStatus(200);
        $response->assertJsonCount(1, 'reports');
        $this->assertEquals('H1', $response->json('reports.0.exam_title'));
    }
}
