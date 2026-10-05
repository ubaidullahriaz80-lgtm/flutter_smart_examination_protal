<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('results', function (Blueprint $table) {
            $table->id();

            // One result per session — also makes GradingService's
            // updateOrCreate() naturally idempotent.
            $table->foreignId('exam_session_id')
                ->unique()
                ->constrained('exam_sessions')
                ->cascadeOnDelete();

            $table->decimal('total_score', 8, 2);
            $table->decimal('max_score', 8, 2);

            // graded: every question is auto-gradable and has been.
            // pending_manual_review: at least one essay/code_snippet
            // answer still needs a human to grade it.
            $table->string('status', 30);

            $table->timestamp('graded_at');

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('results');
    }
};
