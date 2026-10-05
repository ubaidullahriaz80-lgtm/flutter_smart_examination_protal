<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('ai_question_generation_jobs', function (Blueprint $table) {
            $table->timestamp('parsing_at')->nullable()->after('document_name');
            $table->timestamp('generating_at')->nullable()->after('parsing_at');
            $table->timestamp('review_pending_at')->nullable()->after('generating_at');
            $table->timestamp('failed_at')->nullable()->after('status');
        });

        Schema::table('questions', function (Blueprint $table) {
            $table->boolean('is_edited')->default(false)->after('is_ai_generated');
        });
    }

    public function down(): void
    {
        Schema::table('ai_question_generation_jobs', function (Blueprint $table) {
            $table->dropColumn(['parsing_at', 'generating_at', 'review_pending_at', 'failed_at']);
        });

        Schema::table('questions', function (Blueprint $table) {
            $table->dropColumn('is_edited');
        });
    }
};
