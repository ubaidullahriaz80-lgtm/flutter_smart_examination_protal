<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\Exam;
use App\Models\ExamReminder;
use App\Models\User;
use App\Services\FcmService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Mockery;
use Mockery\MockInterface;
use Tests\TestCase;

class ExamReminderTest extends TestCase
{
    use RefreshDatabase;

    protected Department $deptCS;
    protected Department $deptSE;

    protected function setUp(): void
    {
        parent::setUp();
        $this->deptCS = Department::create(['name' => 'Computer Science', 'code' => 'CS']);
        $this->deptSE = Department::create(['name' => 'Software Engineering', 'code' => 'SE']);
    }

    public function test_sends_24h_reminders_correctly(): void
    {
        $candidate = User::factory()->create([
            'role' => 'candidate',
            'department_id' => $this->deptCS->id
        ]);

        // Exam starting in exactly 24 hours
        $exam = Exam::create([
            'created_by' => User::factory()->create(['role' => 'examiner'])->id,
            'title' => 'Biology 101',
            'duration_minutes' => 60,
            'total_marks' => 100,
            'status' => 'published',
            'starts_at' => now()->addHours(24),
            'department_id' => $this->deptCS->id
        ]);

        $this->instance(
            FcmService::class,
            Mockery::mock(FcmService::class, function (MockInterface $mock) use ($candidate) {
                $mock->shouldReceive('sendToUser')
                    ->once()
                    ->with(
                        Mockery::on(fn($u) => $u->id === $candidate->id),
                        Mockery::pattern('/Exam Reminder: Biology 101/'),
                        Mockery::pattern('/starts on/'),
                        Mockery::on(fn($d) => $d['reminder_type'] === '24h')
                    );
            })
        );

        Artisan::call('fsep:send-exam-reminders');

        $this->assertDatabaseHas('exam_reminders', [
            'exam_id' => $exam->id,
            'user_id' => $candidate->id,
            'reminder_type' => '24h',
        ]);
    }

    public function test_sends_1h_reminders_correctly(): void
    {
        $candidate = User::factory()->create([
            'role' => 'candidate',
            'department_id' => $this->deptCS->id
        ]);

        // Exam starting in exactly 1 hour
        $exam = Exam::create([
            'created_by' => User::factory()->create(['role' => 'examiner'])->id,
            'title' => 'Math 101',
            'duration_minutes' => 60,
            'total_marks' => 100,
            'status' => 'published',
            'starts_at' => now()->addHours(1),
            'department_id' => $this->deptCS->id
        ]);

        $this->instance(
            FcmService::class,
            Mockery::mock(FcmService::class, function (MockInterface $mock) use ($candidate) {
                $mock->shouldReceive('sendToUser')
                    ->once()
                    ->with(
                        Mockery::on(fn($u) => $u->id === $candidate->id),
                        Mockery::pattern('/Exam Reminder: Math 101/'),
                        Mockery::pattern('/starts on/'),
                        Mockery::on(fn($d) => $d['reminder_type'] === '1h')
                    );
            })
        );

        Artisan::call('fsep:send-exam-reminders');

        $this->assertDatabaseHas('exam_reminders', [
            'exam_id' => $exam->id,
            'user_id' => $candidate->id,
            'reminder_type' => '1h',
        ]);
    }

    public function test_reminders_respect_department_eligibility(): void
    {
        $candidateCS = User::factory()->create([
            'role' => 'candidate',
            'department_id' => $this->deptCS->id
        ]);
        $candidateSE = User::factory()->create([
            'role' => 'candidate',
            'department_id' => $this->deptSE->id
        ]);

        $examCS = Exam::create([
            'created_by' => User::factory()->create(['role' => 'examiner'])->id,
            'title' => 'CS Exam',
            'duration_minutes' => 60,
            'total_marks' => 100,
            'status' => 'published',
            'starts_at' => now()->addHours(1),
            'department_id' => $this->deptCS->id
        ]);

        $this->instance(
            FcmService::class,
            Mockery::mock(FcmService::class, function (MockInterface $mock) use ($candidateCS) {
                $mock->shouldReceive('sendToUser')
                    ->once()
                    ->with(Mockery::on(fn($u) => $u->id === $candidateCS->id), Mockery::any(), Mockery::any(), Mockery::any());
            })
        );

        Artisan::call('fsep:send-exam-reminders');

        $this->assertDatabaseHas('exam_reminders', ['exam_id' => $examCS->id, 'user_id' => $candidateCS->id]);
        $this->assertDatabaseMissing('exam_reminders', ['exam_id' => $examCS->id, 'user_id' => $candidateSE->id]);
    }

    public function test_reminders_respect_semester_eligibility(): void
    {
        $candidateS3 = User::factory()->create([
            'role' => 'candidate',
            'department_id' => $this->deptCS->id,
            'semester' => 3
        ]);
        $candidateS4 = User::factory()->create([
            'role' => 'candidate',
            'department_id' => $this->deptCS->id,
            'semester' => 4
        ]);

        $examS3 = Exam::create([
            'created_by' => User::factory()->create(['role' => 'examiner'])->id,
            'title' => 'S3 Exam',
            'duration_minutes' => 60,
            'total_marks' => 100,
            'status' => 'published',
            'starts_at' => now()->addHours(1),
            'department_id' => $this->deptCS->id,
            'semester' => 3
        ]);

        $this->instance(
            FcmService::class,
            Mockery::mock(FcmService::class, function (MockInterface $mock) use ($candidateS3) {
                $mock->shouldReceive('sendToUser')
                    ->once()
                    ->with(Mockery::on(fn($u) => $u->id === $candidateS3->id), Mockery::any(), Mockery::any(), Mockery::any());
            })
        );

        Artisan::call('fsep:send-exam-reminders');

        $this->assertDatabaseHas('exam_reminders', ['exam_id' => $examS3->id, 'user_id' => $candidateS3->id]);
        $this->assertDatabaseMissing('exam_reminders', ['exam_id' => $examS3->id, 'user_id' => $candidateS4->id]);
    }

    public function test_does_not_send_duplicate_reminders(): void
    {
        $candidate = User::factory()->create([
            'role' => 'candidate',
            'department_id' => $this->deptCS->id
        ]);

        $exam = Exam::create([
            'created_by' => User::factory()->create(['role' => 'examiner'])->id,
            'title' => 'Duplicate Test',
            'duration_minutes' => 60,
            'total_marks' => 100,
            'status' => 'published',
            'starts_at' => now()->addHours(1),
            'department_id' => $this->deptCS->id
        ]);

        ExamReminder::create([
            'exam_id' => $exam->id,
            'user_id' => $candidate->id,
            'reminder_type' => '1h',
            'sent_at' => now()->subMinutes(5),
        ]);

        $this->instance(
            FcmService::class,
            Mockery::mock(FcmService::class, function (MockInterface $mock) {
                $mock->shouldNotReceive('sendToUser');
            })
        );

        Artisan::call('fsep:send-exam-reminders');
    }

    public function test_only_published_exams_trigger_reminders(): void
    {
        $candidate = User::factory()->create(['role' => 'candidate', 'department_id' => $this->deptCS->id]);

        $exam = Exam::create([
            'created_by' => User::factory()->create(['role' => 'examiner'])->id,
            'title' => 'Draft Exam',
            'duration_minutes' => 60,
            'total_marks' => 100,
            'status' => 'draft',
            'starts_at' => now()->addHours(1),
            'department_id' => $this->deptCS->id
        ]);

        $this->instance(
            FcmService::class,
            Mockery::mock(FcmService::class, function (MockInterface $mock) {
                $mock->shouldNotReceive('sendToUser');
            })
        );

        Artisan::call('fsep:send-exam-reminders');
    }
}
