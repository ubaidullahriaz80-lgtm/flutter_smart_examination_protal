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
        Schema::table('behavior_events', function (Blueprint $table) {
            $table->foreignId('candidate_id')->nullable()->after('client_uuid')->constrained('users')->cascadeOnDelete();
            $table->string('severity', 20)->default('LOW')->after('event_type');
            $table->timestamp('event_timestamp')->nullable()->after('severity');
        });

        // Backfill candidate_id from exam_sessions for existing records
        DB::statement('UPDATE behavior_events SET candidate_id = (SELECT candidate_id FROM exam_sessions WHERE exam_sessions.id = behavior_events.exam_session_id)');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('behavior_events', function (Blueprint $table) {
            $table->dropForeign(['candidate_id']);
            $table->dropColumn(['candidate_id', 'severity', 'event_timestamp']);
        });
    }
};
