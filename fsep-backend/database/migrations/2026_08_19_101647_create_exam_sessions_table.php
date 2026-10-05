<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('exam_sessions', function (Blueprint $table) {
            $table->id();

            $table->foreignId('exam_id')
                ->constrained('exams')
                ->cascadeOnDelete();

            // Candidate this attempt belongs to.
            $table->foreignId('candidate_id')
                ->constrained('users')
                ->cascadeOnDelete();

            // in_progress only for now — submission/grading status values
            // belong to a later phase, not invented here.
            $table->string('status', 20)->default('in_progress');

            $table->timestamp('started_at')->useCurrent();

            $table->timestamps();

            // One session per candidate per exam — lets session
            // creation be idempotent (start-or-resume) instead of
            // creating duplicates.
            $table->unique(['exam_id', 'candidate_id']);
            $table->index(['candidate_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('exam_sessions');
    }
};
