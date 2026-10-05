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
        Schema::table('ai_question_generation_jobs', function (Blueprint $table) {
            $table->json('params')->nullable()->after('chunks');
            $table->json('exam_ids')->nullable()->after('params');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('ai_question_generation_jobs', function (Blueprint $table) {
            $table->dropColumn(['params', 'exam_ids']);
        });
    }
};
