<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('behavior_events', function (Blueprint $table) {
            $table->id();

            // Candidate is derived via exam_session.candidate_id — not
            // duplicated here, same pattern as the existing answers table.
            $table->foreignId('exam_session_id')
                ->constrained('exam_sessions')
                ->cascadeOnDelete();

            $table->string('event_type', 30);

            // Server-assigned (see BehaviorEventController) — never
            // trusted from the client.
            $table->unsignedInteger('suspicion_points')->default(0);

            $table->json('metadata')->nullable();

            $table->timestamps();

            $table->index(['exam_session_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('behavior_events');
    }
};
