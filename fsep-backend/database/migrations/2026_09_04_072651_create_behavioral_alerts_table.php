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
        Schema::create('behavioral_alerts', function (Blueprint $table) {
            $table->id();

            $table->foreignId('exam_session_id')
                ->constrained('exam_sessions')
                ->cascadeOnDelete();

            $table->foreignId('candidate_id')
                ->constrained('users')
                ->cascadeOnDelete();

            $table->integer('risk_score');
            $table->string('risk_band');

            $table->timestamp('triggered_at');

            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('behavioral_alerts');
    }
};
