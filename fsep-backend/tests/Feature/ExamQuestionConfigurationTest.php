<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\Exam;
use App\Models\ExamQuestionConfiguration;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExamQuestionConfigurationTest extends TestCase
{
    use RefreshDatabase;

    protected User $examiner;
    protected Exam $exam;
    protected Department $dept;

    protected function setUp(): void
    {
        parent::setUp();
        $this->dept = Department::create(['name' => 'CS', 'code' => 'CS']);
        $this->examiner = User::factory()->create(['role' => 'examiner', 'department_id' => $this->dept->id]);
        $this->exam = Exam::create([
            'created_by' => $this->examiner->id,
            'department_id' => $this->dept->id,
            'title' => 'Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 100,
            'negative_marking_weight' => 0.25,
            'status' => 'draft'
        ]);
    }

    public function test_teacher_can_create_configuration_for_authorized_exam(): void
    {
        $response = $this->actingAs($this->examiner)->postJson("/api/exams/{$this->exam->id}/question-configurations", [
            'question_type' => 'mcq',
            'question_count' => 10,
            'bloom_taxonomy' => 'analyze',
            'marks' => 2
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('exam_question_configurations', [
            'exam_id' => $this->exam->id,
            'question_type' => 'mcq',
            'question_count' => 10,
            'bloom_taxonomy' => 'analyze',
            'marks' => 2
        ]);
    }

    public function test_teacher_cannot_create_configuration_for_another_departments_exam(): void
    {
        $otherDept = Department::create(['name' => 'SE', 'code' => 'SE']);
        $otherExam = Exam::create([
            'created_by' => User::factory()->create(['role' => 'examiner', 'department_id' => $otherDept->id])->id,
            'department_id' => $otherDept->id,
            'title' => 'Other Exam',
            'duration_minutes' => 60,
            'total_marks' => 100,
            'negative_marking_weight' => 0,
            'status' => 'draft'
        ]);

        $response = $this->actingAs($this->examiner)->postJson("/api/exams/{$otherExam->id}/question-configurations", [
            'question_type' => 'mcq',
            'question_count' => 5,
            'bloom_taxonomy' => 'remember',
            'marks' => 1
        ]);

        $response->assertStatus(403);
    }

    public function test_can_sync_multiple_configurations(): void
    {
        $response = $this->actingAs($this->examiner)->postJson("/api/exams/{$this->exam->id}/question-configurations/sync", [
            'configurations' => [
                [
                    'question_type' => 'mcq',
                    'question_count' => 10,
                    'bloom_taxonomy' => 'remember',
                    'marks' => 1
                ],
                [
                    'question_type' => 'mcq',
                    'question_count' => 5,
                    'bloom_taxonomy' => 'analyze',
                    'marks' => 2
                ],
                [
                    'question_type' => 'short_answer',
                    'question_count' => 5,
                    'bloom_taxonomy' => 'understand',
                    'marks' => 5
                ]
            ]
        ]);

        $response->assertStatus(200);
        $response->assertJsonCount(3, 'question_configurations');
        $this->assertEquals(3, ExamQuestionConfiguration::where('exam_id', $this->exam->id)->count());
    }

    public function test_validation_rules(): void
    {
        // Invalid question count
        $response = $this->actingAs($this->examiner)->postJson("/api/exams/{$this->exam->id}/question-configurations", [
            'question_type' => 'mcq',
            'question_count' => 0,
            'bloom_taxonomy' => 'remember',
            'marks' => 1
        ]);
        $response->assertStatus(422);

        // Invalid bloom level
        $response = $this->actingAs($this->examiner)->postJson("/api/exams/{$this->exam->id}/question-configurations", [
            'question_type' => 'mcq',
            'question_count' => 1,
            'bloom_taxonomy' => 'invalid',
            'marks' => 1
        ]);
        $response->assertStatus(422);
    }
}
