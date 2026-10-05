<?php

namespace App\Console\Commands;

use App\Models\Exam;
use App\Models\ExamReminder;
use App\Models\User;
use App\Services\FcmService;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class SendExamReminders extends Command
{
    protected $signature = 'fsep:send-exam-reminders';

    protected $description = 'Sends 24h and 1h exam reminders to candidates via push notifications.';

    public function handle(FcmService $fcm)
    {
        $this->sendReminders('24h', 24, $fcm);
        $this->sendReminders('1h', 1, $fcm);

        return Command::SUCCESS;
    }

    private function sendReminders(string $type, int $hours, FcmService $fcm)
    {
        $now = now();
        $targetStart = $now->copy()->addHours($hours);

        $exams = Exam::where('status', 'published')
            ->whereNotNull('starts_at')
            ->where('starts_at', '>', $now)
            ->where('starts_at', '<=', $targetStart)
            ->get();

        if ($exams->isEmpty()) {
            return;
        }

        foreach ($exams as $exam) {
            $candidatesQuery = User::where('role', 'candidate')
                ->where('department_id', $exam->department_id);

            if ($exam->semester !== null) {
                $candidatesQuery->where('semester', $exam->semester);
            }

            $candidates = $candidatesQuery->get();

            foreach ($candidates as $candidate) {
                $exists = ExamReminder::where('exam_id', $exam->id)
                    ->where('user_id', $candidate->id)
                    ->where('reminder_type', $type)
                    ->exists();

                if ($exists) {
                    continue;
                }

                $diffInHours = $now->diffInHours($exam->starts_at, false);

                if ($type === '24h' && ($diffInHours < 23 || $diffInHours > 24)) {
                    continue;
                }

                if ($type === '1h' && ($diffInHours < 0 || $diffInHours > 1)) {
                    continue;
                }

                try {
                    DB::transaction(function () use ($exam, $candidate, $type, $fcm) {
                        $lock = ExamReminder::where('exam_id', $exam->id)
                            ->where('user_id', $candidate->id)
                            ->where('reminder_type', $type)
                            ->first();

                        if ($lock) return;

                        ExamReminder::create([
                            'exam_id' => $exam->id,
                            'user_id' => $candidate->id,
                            'reminder_type' => $type,
                            'sent_at' => now(),
                        ]);

                        $startDate = $exam->starts_at->format('F j, Y');
                        $startTime = $exam->starts_at->format('h:i A');
                        $title = "Exam Reminder: {$exam->title}";
                        $body = "Your exam '{$exam->title}' starts on {$startDate} at {$startTime}.";

                        $fcm->sendToUser($candidate, $title, $body, [
                            'type' => 'exam_reminder',
                            'exam_id' => (string) $exam->id,
                            'reminder_type' => $type,
                        ]);
                    });
                } catch (\Throwable $e) {
                    Log::error("Failed to send {$type} reminder for exam {$exam->id} to user {$candidate->id}: " . $e->getMessage());
                }
            }
        }
    }
}
