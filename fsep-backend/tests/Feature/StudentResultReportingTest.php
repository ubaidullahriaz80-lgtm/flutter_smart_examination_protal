<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\ExamSession;
use App\Models\Question;
use App\Models\Result;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class StudentResultReportingTest extends TestCase
{
    use RefreshDatabase;

    public function test_student_result_view_provides_required_fields(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Biology 101',
            'duration_minutes' => 60,
            'total_marks' => 100,
            'pass_percentage' => 60,
        ]);

        $question = Question::create([
            'exam_id' => $exam->id,
            'created_by' => $examiner->id,
            'question_text' => 'Q1',
            'question_type' => 'mcq',
            'marks' => 100,
            'options' => ['A', 'B'],
            'correct_answer' => 'A',
            'review_status' => 'approved',
        ]);

        // Candidate 1: 100% (Pass)
        $c1 = User::factory()->create(['role' => 'candidate']);
        $s1 = ExamSession::create(['exam_id' => $exam->id, 'candidate_id' => $c1->id, 'status' => 'submitted']);
        $s1->answers()->create(['question_id' => $question->id, 'selected_option' => 'A', 'is_correct' => true, 'obtained_marks' => 100, 'grading_status' => 'graded']);
        Result::create(['exam_session_id' => $s1->id, 'total_score' => 100, 'max_score' => 100, 'status' => 'graded', 'graded_at' => now()]);

        // Candidate 2: 0% (Fail)
        $c2 = User::factory()->create(['role' => 'candidate']);
        $s2 = ExamSession::create(['exam_id' => $exam->id, 'candidate_id' => $c2->id, 'status' => 'submitted']);
        $s2->answers()->create(['question_id' => $question->id, 'selected_option' => 'B', 'is_correct' => false, 'obtained_marks' => 0, 'grading_status' => 'graded']);
        Result::create(['exam_session_id' => $s2->id, 'total_score' => 0, 'max_score' => 100, 'status' => 'graded', 'graded_at' => now()]);

        // Candidate 3: 50% (Fail)
        $c3 = User::factory()->create(['role' => 'candidate']);
        $s3 = ExamSession::create(['exam_id' => $exam->id, 'candidate_id' => $c3->id, 'status' => 'submitted']);
        $s3->answers()->create(['question_id' => $question->id, 'selected_option' => 'X', 'is_correct' => false, 'obtained_marks' => 50, 'grading_status' => 'graded']);
        Result::create(['exam_session_id' => $s3->id, 'total_score' => 50, 'max_score' => 100, 'status' => 'graded', 'graded_at' => now()]);

        // Check C1: should be 100th percentile and pass
        $response1 = $this->actingAs($c1)->getJson("/api/results/{$s1->id}");
        $response1->assertStatus(200)
            ->assertJsonPath('result.percentile', 100)
            ->assertJsonPath('result.pass_fail', 'pass')
            ->assertJsonStructure(['result' => ['question_results']]);

        // Check C3: should be 66.7th percentile and fail
        // Cohort scores: 0, 50, 100.
        // C3 total_score = 50. Scores <= 50: {0, 50} (count 2).
        // Total students: 3. Percentile = 2 / 3 * 100 = 66.7.
        $response3 = $this->actingAs($c3)->getJson("/api/results/{$s3->id}");
        $response3->assertStatus(200)
            ->assertJsonPath('result.percentile', 66.7)
            ->assertJsonPath('result.pass_fail', 'fail');

        // Check C2: should be 33.3rd percentile and fail
        // Scores <= 0: {0} (count 1).
        // Percentile = 1 / 3 * 100 = 33.3.
        $response2 = $this->actingAs($c2)->getJson("/api/results/{$s2->id}");
        $response2->assertStatus(200)
            ->assertJsonPath('result.percentile', 33.3)
            ->assertJsonPath('result.pass_fail', 'fail');
    }
}
