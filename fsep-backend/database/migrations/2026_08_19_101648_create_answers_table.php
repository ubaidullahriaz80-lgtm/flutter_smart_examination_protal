<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('answers', function (Blueprint $table) {
            $table->id();

            $table->foreignId('exam_session_id')
                ->constrained('exam_sessions')
                ->cascadeOnDelete();

            $table->foreignId('question_id')
                ->constrained('questions')
                ->cascadeOnDelete();

            // The candidate's chosen option value (MCQ) or free-text
            // answer. Deliberately no is_correct/obtained_marks columns —
            // grading is a separate, later concern that reads this against
            // questions.correct_answer server-side; it is never computed
            // or exposed here.
            $table->text('selected_option');

            $table->timestamps();

            // One answer row per question per session — lets saving an
            // answer be an upsert (select/change before submission)
            // instead of creating duplicate rows.
            $table->unique(['exam_session_id', 'question_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('answers');
    }
};
