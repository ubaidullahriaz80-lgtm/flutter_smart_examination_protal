<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('questions', function (Blueprint $table) {
            $table->id();

            $table->foreignId('exam_id')
                ->constrained('exams')
                ->cascadeOnDelete();

            $table->foreignId('created_by')
                ->constrained('users')
                ->cascadeOnDelete();

            $table->text('question_text');

            $table->enum('question_type', [
                'mcq',
                'true_false',
                'short_answer',
                'essay',
                'matching',
                'code_snippet',
            ]);

            $table->unsignedInteger('marks')->default(1);

            $table->string('difficulty')->default('medium');

            $table->string('bloom_taxonomy')->nullable();

            $table->string('topic_tag')->nullable();

            $table->json('options')->nullable();

            $table->text('correct_answer')->nullable();

            $table->boolean('is_ai_generated')->default(false);

            $table->enum('review_status', [
                'pending',
                'approved',
                'rejected',
            ])->default('pending');

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('questions');
    }
};