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
            $table->json('chunks')->nullable()->after('document_name');
            $table->text('last_error')->nullable()->after('status');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('ai_question_generation_jobs', function (Blueprint $table) {
            $table->dropColumn(['chunks', 'last_error']);
        });
    }
};
