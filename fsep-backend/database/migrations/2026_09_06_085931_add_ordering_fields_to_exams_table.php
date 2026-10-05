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
        Schema::table('exams', function (Blueprint $table) {
            $table->boolean('randomize_questions')->default(false)->after('bcd_enabled');
            $table->boolean('shuffle_choices')->default(false)->after('randomize_questions');

            // FR-EA-01: unique alpha-numeric title
            $table->unique('title');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('exams', function (Blueprint $table) {
            $table->dropUnique(['title']);
            $table->dropColumn(['randomize_questions', 'shuffle_choices']);
        });
    }
};
