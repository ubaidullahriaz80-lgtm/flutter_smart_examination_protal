<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('exam_sessions', function (Blueprint $table) {
            // Set once, when the candidate explicitly submits (or a future
            // auto-submit-on-timeout feature does so) — null until then.
            // No new status system: 'submitted' is just an additional
            // value for the existing status column.
            $table->timestamp('submitted_at')->nullable()->after('expires_at');
        });
    }

    public function down(): void
    {
        Schema::table('exam_sessions', function (Blueprint $table) {
            $table->dropColumn('submitted_at');
        });
    }
};
