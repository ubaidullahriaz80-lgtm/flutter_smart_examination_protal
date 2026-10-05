<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('answers', function (Blueprint $table) {
            // 'ungraded' until the session is submitted and GradingService
            // runs; then 'graded' (auto-gradable types) or
            // 'pending_manual_review' (essay/code_snippet).
            $table->string('grading_status', 20)->default('ungraded')->after('selected_option');

            // Null until graded. True/false; null for pending-review
            // answers (correctness isn't known yet).
            $table->boolean('is_correct')->nullable()->after('grading_status');

            // Null until graded. Can be negative (negative marking) for an
            // incorrect auto-graded answer; null while pending review so a
            // pending answer is never mistaken for "graded as zero".
            $table->decimal('obtained_marks', 8, 2)->nullable()->after('is_correct');
        });
    }

    public function down(): void
    {
        Schema::table('answers', function (Blueprint $table) {
            $table->dropColumn(['grading_status', 'is_correct', 'obtained_marks']);
        });
    }
};
