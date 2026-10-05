<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExamPlatformVisibilityTest extends TestCase
{
    use RefreshDatabase;

    public function test_exam_platform_visibility_can_be_configured(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);

        $response = $this->actingAs($examiner)->postJson('/api/exams', [
            'title' => 'Cross-platform Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
            'status' => 'published',
            'allowed_platforms' => ['android', 'ios']
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('exams', [
            'title' => 'Cross-platform Exam',
        ]);

        $exam = Exam::where('title', 'Cross-platform Exam')->first();
        $this->assertEquals(['android', 'ios'], $exam->allowed_platforms);
    }

    public function test_candidate_on_allowed_platform_can_see_exam(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Android Only',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'status' => 'published',
            'allowed_platforms' => ['android']
        ]);

        $candidate = User::factory()->create(['role' => 'candidate']);

        $response = $this->actingAs($candidate)
            ->withHeader('X-App-Platform', 'android')
            ->getJson('/api/exams');

        $response->assertStatus(200);
        $response->assertJsonCount(1, 'exams');
        $response->assertJsonFragment(['title' => 'Android Only']);
    }

    public function test_candidate_on_disallowed_platform_cannot_see_exam(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Desktop Only',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'status' => 'published',
            'allowed_platforms' => ['windows', 'macos']
        ]);

        $candidate = User::factory()->create(['role' => 'candidate']);

        $response = $this->actingAs($candidate)
            ->withHeader('X-App-Platform', 'android')
            ->getJson('/api/exams');

        $response->assertStatus(200);
        $response->assertJsonCount(0, 'exams');
    }

    public function test_null_allowed_platforms_means_visible_to_all(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Universal Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'status' => 'published',
            'allowed_platforms' => null
        ]);

        $candidate = User::factory()->create(['role' => 'candidate']);

        $response = $this->actingAs($candidate)
            ->withHeader('X-App-Platform', 'web')
            ->getJson('/api/exams');

        $response->assertStatus(200);
        $response->assertJsonCount(1, 'exams');
    }

    public function test_candidate_on_disallowed_platform_cannot_view_exam_details(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'iOS Only',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'status' => 'published',
            'allowed_platforms' => ['ios']
        ]);

        $candidate = User::factory()->create(['role' => 'candidate']);

        $response = $this->actingAs($candidate)
            ->withHeader('X-App-Platform', 'android')
            ->getJson("/api/exams/{$exam->id}");

        $response->assertStatus(403);
        $response->assertJsonPath('message', 'This exam is not available on your platform.');
    }
}
