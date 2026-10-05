<?php

use App\Models\ExamSession;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('exam_sessions', function (Blueprint $table) {
            // Server-authoritative deadline for this attempt, fixed at
            // start/resume time from the exam's duration_minutes — the
            // timer/expiry check must always read this, never re-derive
            // "now + duration" on every request.
            $table->timestamp('expires_at')->nullable()->after('started_at');
        });

        // Backfill sessions created before this column existed, so
        // existing rows aren't left with an unusable null deadline.
        ExamSession::with('exam')->whereNull('expires_at')->get()->each(function (ExamSession $session) {
            if ($session->exam) {
                $session->expires_at = $session->started_at
                    ->copy()
                    ->addMinutes($session->exam->duration_minutes);
                $session->saveQuietly();
            }
        });
    }

    public function down(): void
    {
        Schema::table('exam_sessions', function (Blueprint $table) {
            $table->dropColumn('expires_at');
        });
    }
};
