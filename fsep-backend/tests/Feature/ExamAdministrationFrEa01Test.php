<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExamAdministrationFrEa01Test extends TestCase
{
    use RefreshDatabase;

    public function test_examiner_can_configure_fr_ea_01_fields(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);

        $response = $this->actingAs($examiner)->postJson('/api/exams', [
            'title' => 'Math 101',
            'description' => 'A basic math exam',
            'course_code' => 'MATH101',
            'duration_minutes' => 60,
            'total_marks' => 100,
            'negative_marking_weight' => 0.25,
            'randomize_questions' => true,
            'shuffle_choices' => true,
            'status' => 'published',
        ]);

        $response->assertStatus(201);
        $response->assertJsonPath('exam.title', 'Math 101');
        $response->assertJsonPath('exam.randomize_questions', true);
        $response->assertJsonPath('exam.shuffle_choices', true);

        $this->assertDatabaseHas('exams', [
            'title' => 'Math 101',
            'randomize_questions' => true,
            'shuffle_choices' => true,
        ]);
    }

    public function test_exam_title_must_be_unique(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        Exam::factory()->create(['title' => 'Biology 101']);

        $response = $this->actingAs($examiner)->postJson('/api/exams', [
            'title' => 'Biology 101',
            'duration_minutes' => 60,
            'total_marks' => 100,
            'negative_marking_weight' => 0,
        ]);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors(['title']);
    }

    public function test_exam_title_must_be_alpha_numeric(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);

        $response = $this->actingAs($examiner)->postJson('/api/exams', [
            'title' => 'Math #101!', // Invalid characters
            'duration_minutes' => 60,
            'total_marks' => 100,
            'negative_marking_weight' => 0,
        ]);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors(['title']);
    }

    public function test_can_update_exam_with_fr_ea_01_fields(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::factory()->create(['created_by' => $examiner->id, 'randomize_questions' => false]);

        $response = $this->actingAs($examiner)->putJson("/api/exams/{$exam->id}", [
            'title' => 'Updated Title',
            'duration_minutes' => 90,
            'total_marks' => 50,
            'negative_marking_weight' => 0.5,
            'randomize_questions' => true,
            'shuffle_choices' => false,
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('exams', [
            'id' => $exam->id,
            'title' => 'Updated Title',
            'randomize_questions' => true,
        ]);
    }
}
