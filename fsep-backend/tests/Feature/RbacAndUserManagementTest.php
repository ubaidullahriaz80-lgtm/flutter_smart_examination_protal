<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Concerns\CreatesTestUsers;
use Tests\TestCase;

/**
 * RBAC boundary checks (FR-UM-03) plus User Management CRUD + CSV import.
 */
class RbacAndUserManagementTest extends TestCase
{
    use RefreshDatabase;
    use CreatesTestUsers;

    public function test_candidate_is_forbidden_from_user_management(): void
    {
        [, $token] = $this->makeUserWithToken('candidate');

        $this->getJson('/api/users', $this->authHeaders($token))->assertStatus(403);
    }

    public function test_examiner_is_forbidden_from_user_management(): void
    {
        [, $token] = $this->makeUserWithToken('examiner');

        $this->getJson('/api/users', $this->authHeaders($token))->assertStatus(403);
    }

    public function test_system_administrator_can_list_users(): void
    {
        [, $token] = $this->makeUserWithToken('system_administrator');

        $this->getJson('/api/users', $this->authHeaders($token))->assertStatus(200);
    }

    public function test_system_administrator_can_create_edit_and_delete_a_user(): void
    {
        [, $token] = $this->makeUserWithToken('system_administrator');
        $headers = $this->authHeaders($token);

        $create = $this->postJson('/api/users', [
            'name' => 'Managed User',
            'email' => 'managed@test.local',
            'password' => 'password123',
            'role' => 'candidate',
        ], $headers);
        $create->assertStatus(201);
        $id = $create->json('user.id');

        $this->putJson("/api/users/{$id}", [
            'name' => 'Managed User Edited',
            'email' => 'managed@test.local',
            'role' => 'examiner',
        ], $headers)->assertStatus(200)->assertJson(['user' => ['role' => 'examiner']]);

        $this->deleteJson("/api/users/{$id}", [], $headers)->assertStatus(204);
        $this->assertDatabaseMissing('users', ['id' => $id]);
    }

    public function test_a_user_cannot_delete_their_own_account(): void
    {
        [$user, $token] = $this->makeUserWithToken('system_administrator');

        $this->deleteJson("/api/users/{$user->id}", [], $this->authHeaders($token))
            ->assertStatus(422);
    }

    public function test_csv_import_creates_valid_rows_and_reports_invalid_ones(): void
    {
        [, $token] = $this->makeUserWithToken('system_administrator');

        $csv = "name,email,password,role\n"
            ."CSV Good,csvgood@test.local,password123,candidate\n"
            .",bademail,short,not_a_role\n";

        $file = \Illuminate\Http\UploadedFile::fake()->createWithContent('users.csv', $csv);

        $response = $this->post('/api/users/import', ['file' => $file], $this->authHeaders($token));

        $response->assertStatus(200)
            ->assertJson(['imported_count' => 1, 'failed_count' => 1]);
        $this->assertDatabaseHas('users', ['email' => 'csvgood@test.local', 'role' => 'candidate']);
    }
}
