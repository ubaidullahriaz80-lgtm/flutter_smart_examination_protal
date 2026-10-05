<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('learning_gap_reports', function (Blueprint $table) {
            $table->id();

            // One report per session (per SRS §4.3.5 and persistence requirement).
            $table->foreignId('exam_session_id')
                ->unique()
                ->constrained('exam_sessions')
                ->cascadeOnDelete();

            $table->foreignId('candidate_id')
                ->constrained('users')
                ->cascadeOnDelete();

            $table->foreignId('exam_id')
                ->constrained('exams')
                ->cascadeOnDelete();

            // Persisted data as required by FR-LGD-08.
            $table->json('learning_gaps');
            $table->json('all_topics');
            $table->json('bloom_profile');
            $table->json('difficulty_profile');
            $table->json('improvement_roadmap');

            $table->integer('topics_analyzed');
            $table->integer('questions_attempted');

            $table->timestamp('generated_at')->useCurrent();
            $table->timestamps();

            $table->index(['candidate_id', 'exam_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('learning_gap_reports');
    }
};
