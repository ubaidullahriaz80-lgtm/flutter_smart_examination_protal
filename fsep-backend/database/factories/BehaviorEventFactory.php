<?php

namespace Database\Factories;

use App\Models\ExamSession;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends \Illuminate\Database\Eloquent\Factories\Factory<\App\Models\BehaviorEvent>
 */
class BehaviorEventFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'exam_session_id' => ExamSession::factory(),
            'candidate_id' => User::factory(),
            'client_uuid' => fake()->uuid(),
            'event_type' => 'focus_lost',
            'severity' => 'LOW',
            'event_timestamp' => now(),
            'suspicion_points' => 10,
        ];
    }
}
