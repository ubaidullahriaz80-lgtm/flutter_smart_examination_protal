<?php

namespace Tests\Concerns;

use App\Models\User;
use Illuminate\Support\Facades\Auth;

/**
 * Shared helper for Feature tests — creates a real User row with a real
 * Sanctum token for a given role, mirroring exactly how DatabaseSeeder
 * creates role accounts (create() then set ->role directly, since role
 * isn't in the model's mass-assignable $fillable list).
 */
trait CreatesTestUsers
{
    protected function makeUserWithToken(string $role, ?string $email = null): array
    {
        $user = User::create([
            'name' => ucfirst(str_replace('_', ' ', $role)).' Test User',
            'email' => $email ?? $role.'+'.uniqid().'@test.local',
            'password' => bcrypt('password123'),
        ]);
        $user->role = $role;
        $user->save();

        $token = $user->createToken('test')->plainTextToken;

        return [$user, $token];
    }

    /**
     * The Sanctum guard caches its resolved user for the lifetime of the
     * test's Application instance, not per-request — so within a single
     * test method, a second request authenticated as a *different*
     * user's token would otherwise still resolve as whoever the guard
     * resolved first. forgetGuards() forces a fresh resolution from
     * whatever Bearer token the next request actually carries, which is
     * exactly what every test in this suite that exercises more than one
     * role needs.
     */
    protected function authHeaders(string $token): array
    {
        Auth::forgetGuards();

        return ['Authorization' => 'Bearer '.$token];
    }
}
