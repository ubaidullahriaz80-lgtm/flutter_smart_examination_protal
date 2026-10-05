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
        Schema::create('exams', function (Blueprint $table) {
            $table->id();

            // User who created the exam.
            $table->foreignId('created_by')
                ->constrained('users')
                ->cascadeOnDelete();

            $table->string('title');

            $table->text('description')->nullable();

            $table->string('course_code', 50)->nullable();

            // Exam duration in minutes.
            $table->unsignedInteger('duration_minutes');

            $table->decimal('total_marks', 8, 2)->default(0);

            // Example: 0.25 means 25% of the question marks
            // are deducted for an incorrect answer.
            $table->decimal('negative_marking_weight', 5, 2)->default(0);

            // draft → published → closed
            $table->string('status', 20)->default('draft');

            $table->timestamp('starts_at')->nullable();

            $table->timestamp('ends_at')->nullable();

            $table->timestamps();

            $table->index(['status']);
            $table->index(['created_by']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('exams');
    }
};