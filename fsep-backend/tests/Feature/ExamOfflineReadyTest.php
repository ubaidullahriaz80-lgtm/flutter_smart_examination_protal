<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExamOfflineReadyTest extends TestCase
{
    use RefreshDatabase;

    public function test_examiner_can_configure_offline_ready_flag(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);

        $response = $this->actingAs($examiner)->postJson('/api/exams', [
            'title' => 'Offline Exam',
            'duration_minutes' => 60,
            'total_marks' => 100,
            'negative_marking_weight' => 0,
            'is_offline_ready' => true,
        ]);

        $response->assertStatus(201);
        $response->assertJsonPath('exam.is_offline_ready', true);
        $this->assertDatabaseHas('exams', ['title' => 'Offline Exam', 'is_offline_ready' => true]);
    }

    public function test_offline_ready_flag_defaults_to_false(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);

        $response = $this->actingAs($examiner)->postJson('/api/exams', [
            'title' => 'Online Only Exam',
            'duration_minutes' => 60,
            'total_marks' => 100,
            'negative_marking_weight' => 0,
        ]);

        $response->assertStatus(201);
        $response->assertJsonPath('exam.is_offline_ready', false);
    }
}
