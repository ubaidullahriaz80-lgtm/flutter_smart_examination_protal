<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('exam_reminders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('exam_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('reminder_type'); // '24h' or '1h'
            $table->timestamp('sent_at');
            $table->timestamps();

            $table->unique(['exam_id', 'user_id', 'reminder_type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('exam_reminders');
    }
};
