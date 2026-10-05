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
        Schema::create('behavioral_review_actions', function (Blueprint $table) {
            $table->id();

            $table->foreignId('event_id')
                ->constrained('behavior_events')
                ->cascadeOnDelete();

            $table->foreignId('invigilator_id')
                ->constrained('users')
                ->cascadeOnDelete();

            // Reviewed | Escalated | Dismissed
            $table->string('action', 20);

            $table->text('note')->nullable();

            $table->timestamp('actioned_at');

            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('behavioral_review_actions');
    }
};
