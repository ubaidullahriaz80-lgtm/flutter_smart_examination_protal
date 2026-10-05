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
        Schema::create('behavioral_risk_scores', function (Blueprint $table) {
            $table->id();

            $table->foreignId('exam_session_id')
                ->unique()
                ->constrained('exam_sessions')
                ->cascadeOnDelete();

            $table->integer('risk_score');

            $table->enum('risk_band', ['low', 'medium', 'high', 'critical']);

            $table->timestamp('computed_at');

            $table->json('event_breakdown'); // Per-category contribution

            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('behavioral_risk_scores');
    }
};
