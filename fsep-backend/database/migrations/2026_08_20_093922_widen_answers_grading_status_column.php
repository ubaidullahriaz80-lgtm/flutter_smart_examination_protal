<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 'pending_manual_review' is 21 characters — the original
        // string(20) was too narrow and truncated on write.
        Schema::table('answers', function (Blueprint $table) {
            $table->string('grading_status', 30)->default('ungraded')->change();
        });
    }

    public function down(): void
    {
        Schema::table('answers', function (Blueprint $table) {
            $table->string('grading_status', 20)->default('ungraded')->change();
        });
    }
};
