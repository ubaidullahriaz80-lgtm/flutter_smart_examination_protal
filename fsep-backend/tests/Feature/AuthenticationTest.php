<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesTestUsers;
use Tests\TestCase;

/**
 * FR-UM-01/FR-UM-02: login. Public self-service registration is disabled.
 */
class AuthenticationTest extends TestCase
{
    use RefreshDatabase;
    use CreatesTestUsers;

    public function test_login_succeeds_with_correct_credentials_and_returns_role(): void
    {
        [$user] = $this->makeUserWithToken('candidate', 'login-ok@test.local');

        $response = $this->postJson('/api/auth/login', [
            'email' => 'login-ok@test.local',
            'password' => 'password123',
        ]);

        $response->assertStatus(200)
            ->assertJson(['role' => 'candidate'])
            ->assertJsonStructure(['jwt_token', 'role', 'user_id']);
    }

    public function test_login_fails_with_wrong_password(): void
    {
        $this->makeUserWithToken('candidate', 'wrongpass@test.local');

        $response = $this->postJson('/api/auth/login', [
            'email' => 'wrongpass@test.local',
            'password' => 'not-the-password',
        ]);

        $response->assertStatus(401);
    }

    public function test_registration_endpoint_is_disabled(): void
    {
        $response = $this->postJson('/api/auth/register', [
            'name' => 'New Candidate',
            'email' => 'newcandidate@test.local',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response->assertStatus(404);
    }

    public function test_unauthenticated_request_to_a_protected_route_returns_401(): void
    {
        $response = $this->getJson('/api/users');

        $response->assertStatus(401);
    }
}
