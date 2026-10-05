<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\DeviceToken;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DeviceTokenRegistrationTest extends TestCase
{
    use RefreshDatabase;

    public function test_authenticated_user_can_register_device_token(): void
    {
        $user = User::factory()->create();
        $token = 'fcm-test-token';

        $response = $this->actingAs($user)->postJson('/api/device-tokens', [
            'token' => $token,
            'platform' => 'android',
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('device_tokens', [
            'user_id' => $user->id,
            'token' => $token,
            'platform' => 'android',
        ]);
    }

    public function test_registering_same_token_updates_last_used_at(): void
    {
        $user = User::factory()->create();
        $token = 'fcm-test-token';

        DeviceToken::create([
            'user_id' => $user->id,
            'token' => $token,
            'platform' => 'ios',
            'last_used_at' => now()->subDays(1),
        ]);

        $response = $this->actingAs($user)->postJson('/api/device-tokens', [
            'token' => $token,
            'platform' => 'android', // Update platform
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseCount('device_tokens', 1);
        $this->assertDatabaseHas('device_tokens', [
            'token' => $token,
            'platform' => 'android',
        ]);
    }

    public function test_unauthenticated_user_cannot_register_token(): void
    {
        $response = $this->postJson('/api/device-tokens', [
            'token' => 'some-token',
        ]);

        $response->assertStatus(401);
    }

    public function test_user_can_unregister_token(): void
    {
        $user = User::factory()->create();
        $token = 'fcm-test-token';

        DeviceToken::create([
            'user_id' => $user->id,
            'token' => $token,
        ]);

        $response = $this->actingAs($user)->deleteJson('/api/device-tokens', [
            'token' => $token,
        ]);

        $response->assertStatus(204);
        $this->assertDatabaseMissing('device_tokens', ['token' => $token]);
    }
}
