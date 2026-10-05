<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\ExamSession;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Concerns\CreatesTestUsers;
use Tests\TestCase;

class BehaviorEventSyncTest extends TestCase
{
    use RefreshDatabase;
    use CreatesTestUsers;

    private function startExamSession(): array
    {
        [$examiner] = $this->makeUserWithToken('examiner');
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'BCD Sync Test',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
            'status' => 'published',
        ]);
        [, $candidateToken] = $this->makeUserWithToken('candidate');
        $headers = $this->authHeaders($candidateToken);

        $sessionId = $this->postJson("/api/exams/{$exam->id}/session", [], $headers)
            ->json('session.id');

        return [$sessionId, $headers];
    }

    public function test_authenticated_candidate_can_sync_behavior_events(): void
    {
        [$sessionId, $headers] = $this->startExamSession();
        $uuid1 = Str::uuid()->toString();
        $uuid2 = Str::uuid()->toString();

        $response = $this->postJson(
            "/api/exam-sessions/{$sessionId}/behavior-events/sync",
            [
                'events' => [
                    [
                        'client_uuid' => $uuid1,
                        'event_type' => 'focus_lost',
                        'occurred_at' => now()->toIso8601String(),
                    ],
                    [
                        'client_uuid' => $uuid2,
                        'event_type' => 'navigation_away',
                        'occurred_at' => now()->toIso8601String(),
                    ],
                ]
            ],
            $headers
        );

        $response->assertStatus(200);
        $this->assertDatabaseHas('behavior_events', ['client_uuid' => $uuid1, 'exam_session_id' => $sessionId]);
        $this->assertDatabaseHas('behavior_events', ['client_uuid' => $uuid2, 'exam_session_id' => $sessionId]);
    }

    public function test_duplicate_sync_does_not_create_duplicate_events(): void
    {
        [$sessionId, $headers] = $this->startExamSession();
        $uuid = Str::uuid()->toString();

        $payload = [
            'events' => [
                [
                    'client_uuid' => $uuid,
                    'event_type' => 'focus_lost',
                    'occurred_at' => now()->toIso8601String(),
                ],
            ]
        ];

        $this->postJson("/api/exam-sessions/{$sessionId}/behavior-events/sync", $payload, $headers)
            ->assertStatus(200);

        $this->postJson("/api/exam-sessions/{$sessionId}/behavior-events/sync", $payload, $headers)
            ->assertStatus(200);

        $this->assertDatabaseCount('behavior_events', 1);
    }

    public function test_expired_session_returns_conflict_per_event(): void
    {
        [$sessionId, $headers] = $this->startExamSession();
        ExamSession::whereKey($sessionId)->update(['status' => 'submitted']);

        $uuid = Str::uuid()->toString();
        $response = $this->postJson(
            "/api/exam-sessions/{$sessionId}/behavior-events/sync",
            [
                'events' => [
                    [
                        'client_uuid' => $uuid,
                        'event_type' => 'focus_lost',
                        'occurred_at' => now()->toIso8601String(),
                    ],
                ]
            ],
            $headers
        );

        $response->assertStatus(200)->assertJsonFragment([
            'client_uuid' => $uuid,
            'status' => 'conflict',
            'code' => 'CONFLICT_SESSION_CLOSED',
        ]);
        $this->assertDatabaseMissing('behavior_events', ['client_uuid' => $uuid]);
    }
}
