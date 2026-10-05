<?php

namespace Tests\Feature;

use App\Models\Exam;
use App\Models\ExamSession;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SrsComplianceBcdTest extends TestCase
{
    use RefreshDatabase;

    public function test_all_srs_event_types_are_accepted(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'T',
            'duration_minutes' => 60,
            'bcd_enabled' => true,
        ]);

        $candidate = User::factory()->create(['role' => 'candidate']);
        $session = ExamSession::create([
            'exam_id' => $exam->id,
            'candidate_id' => $candidate->id,
            'status' => 'in_progress',
            'expires_at' => now()->addHour(),
        ]);

        $eventTypes = [
            'RapidAnswerChange',
            'ExcessiveQuestionSwitch',
            'UnusualAnsweringSpeed',
            'TabSwitchAttempt',
            'WindowFocusLoss',
            'IdlePeriod',
            'DeviceChange'
        ];

        foreach ($eventTypes as $type) {
            $response = $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", [
                'event_type' => $type,
                'metadata' => ['test' => true]
            ]);

            $response->assertStatus(201);
            $this->assertDatabaseHas('behavior_events', [
                'exam_session_id' => $session->id,
                'candidate_id' => $candidate->id,
                'event_type' => $type,
                'severity' => match ($type) {
                    'DeviceChange' => 'CRITICAL',
                    'TabSwitchAttempt', 'WindowFocusLoss' => 'HIGH',
                    'RapidAnswerChange', 'ExcessiveQuestionSwitch' => 'MEDIUM',
                    default => 'LOW',
                }
            ]);
        }
    }

    public function test_unsupported_event_type_is_rejected(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'T', 'duration_minutes' => 60, 'bcd_enabled' => true]);
        $candidate = User::factory()->create(['role' => 'candidate']);
        $session = ExamSession::create(['exam_id' => $exam->id, 'candidate_id' => $candidate->id, 'status' => 'in_progress', 'expires_at' => now()->addHour()]);

        $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", [
            'event_type' => 'MaliciousActivity'
        ])->assertStatus(422);
    }

    public function test_bcd_events_require_enabled_toggle(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create(['created_by' => $examiner->id, 'title' => 'T', 'duration_minutes' => 60, 'bcd_enabled' => false]);
        $candidate = User::factory()->create(['role' => 'candidate']);
        $session = ExamSession::create(['exam_id' => $exam->id, 'candidate_id' => $candidate->id, 'status' => 'in_progress', 'expires_at' => now()->addHour()]);

        $this->actingAs($candidate)->postJson("/api/exam-sessions/{$session->id}/behavior-events", [
            'event_type' => 'WindowFocusLoss'
        ])->assertStatus(422);
    }
}
