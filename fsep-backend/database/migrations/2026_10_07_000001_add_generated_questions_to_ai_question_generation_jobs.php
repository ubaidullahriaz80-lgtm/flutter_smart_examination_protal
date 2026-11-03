<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('ai_question_generation_jobs', function (Blueprint $table) {
            $table->json('generated_questions')->nullable()->after('chunks');
        });
    }

    public function down(): void
    {
        Schema::table('ai_question_generation_jobs', function (Blueprint $table) {
            $table->dropColumn('generated_questions');
        });
    }
};