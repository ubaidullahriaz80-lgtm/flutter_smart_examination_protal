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
        Schema::create('ai_question_generation_jobs', function (Blueprint $table) {
            $table->id();

            $table->foreignId('examiner_id')
                ->constrained('users')
                ->cascadeOnDelete();

            $table->string('document_name')->nullable();

            // Status states defined in SRS FR-QG-09
            $table->enum('status', [
                'UPLOADING',
                'PARSING',
                'GENERATING',
                'REVIEW_PENDING',
                'COMPLETED',
                'FAILED'
            ])->default('UPLOADING');

            $table->unsignedInteger('questions_generated')->default(0);
            $table->unsignedInteger('questions_approved')->default(0);
            $table->unsignedInteger('questions_rejected')->default(0);

            $table->timestamp('completed_at')->nullable();
            $table->timestamps();

            $table->index(['examiner_id']);
            $table->index(['status']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('ai_question_generation_jobs');
    }
};
