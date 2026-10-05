<?php

namespace Tests\Feature;

use App\Models\Exam;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesTestUsers;
use Tests\TestCase;

/**
 * Exam Administration CRUD + Question Bank CRUD, including per-type
 * validation for the 6 supported question types.
 */
class ExamQuestionAdministrationTest extends TestCase
{
    use RefreshDatabase;
    use CreatesTestUsers;

    private function makeExam(): Exam
    {
        [$examiner] = $this->makeUserWithToken('examiner');

        return Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Test Exam',
            'course_code' => 'CS101',
            'duration_minutes' => 60,
            'total_marks' => 100,
            'negative_marking_weight' => 0.25,
            'pass_percentage' => 50,
            'status' => 'draft',
        ]);
    }

    public function test_examiner_can_create_edit_and_delete_an_exam(): void
    {
        [, $token] = $this->makeUserWithToken('examiner');
        $headers = $this->authHeaders($token);

        $create = $this->postJson('/api/exams', [
            'title' => 'New Exam',
            'duration_minutes' => 30,
            'total_marks' => 50,
            'negative_marking_weight' => 0,
            'pass_percentage' => 40,
        ], $headers);
        $create->assertStatus(201);
        $id = $create->json('exam.id');
        $this->assertEquals(40, $create->json('exam.pass_percentage'));

        $this->putJson("/api/exams/{$id}", [
            'title' => 'New Exam Edited',
            'duration_minutes' => 45,
            'total_marks' => 50,
            'negative_marking_weight' => 0,
            'pass_percentage' => 75,
        ], $headers)->assertStatus(200);

        $this->assertEquals(75, Exam::find($id)->pass_percentage);

        $this->deleteJson("/api/exams/{$id}", [], $headers)->assertStatus(204);
    }

    public function test_candidate_cannot_create_an_exam(): void
    {
        [, $token] = $this->makeUserWithToken('candidate');

        $this->postJson('/api/exams', [
            'title' => 'Should Fail',
            'duration_minutes' => 30,
            'total_marks' => 50,
            'negative_marking_weight' => 0,
        ], $this->authHeaders($token))->assertStatus(403);
    }

    public function test_mcq_question_requires_at_least_two_options_and_a_matching_correct_answer(): void
    {
        [$examiner, $token] = $this->makeUserWithToken('examiner');
        $exam = $this->makeExam();
        $headers = $this->authHeaders($token);

        $this->postJson('/api/questions', [
            'exam_id' => $exam->id,
            'question_text' => 'Bad MCQ',
            'question_type' => 'mcq',
            'marks' => 5,
            'difficulty' => 'easy',
            'bloom_taxonomy' => 'remember',
            'options' => ['Only one'],
            'correct_answer' => 'Only one',
        ], $headers)->assertStatus(422);

        $good = $this->postJson('/api/questions', [
            'exam_id' => $exam->id,
            'question_text' => 'Good MCQ',
            'question_type' => 'mcq',
            'marks' => 5,
            'difficulty' => 'easy',
            'bloom_taxonomy' => 'remember',
            'options' => ['A', 'B', 'C'],
            'correct_answer' => 'B',
        ], $headers);

        $good->assertStatus(201)->assertJson([
            'question' => ['is_ai_generated' => false, 'review_status' => 'pending'],
        ]);
    }

    public function test_matching_question_derives_a_canonical_correct_answer_server_side(): void
    {
        [, $token] = $this->makeUserWithToken('examiner');
        $exam = $this->makeExam();

        $response = $this->postJson('/api/questions', [
            'exam_id' => $exam->id,
            'question_text' => 'Match capitals',
            'question_type' => 'matching',
            'marks' => 6,
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'remember',
            'options' => [
                ['left' => 'Pakistan', 'right' => 'Islamabad'],
                ['left' => 'France', 'right' => 'Paris'],
            ],
        ], $this->authHeaders($token));

        $response->assertStatus(201);
        $this->assertSame(
            '{"Pakistan":"Islamabad","France":"Paris"}',
            $response->json('question.correct_answer'),
        );
    }

    public function test_true_false_question_requires_exactly_true_or_false(): void
    {
        [, $token] = $this->makeUserWithToken('examiner');
        $exam = $this->makeExam();

        $this->postJson('/api/questions', [
            'exam_id' => $exam->id,
            'question_text' => 'Bad T/F',
            'question_type' => 'true_false',
            'marks' => 5,
            'difficulty' => 'easy',
            'bloom_taxonomy' => 'remember',
            'correct_answer' => 'Maybe',
        ], $this->authHeaders($token))->assertStatus(422);
    }
}
