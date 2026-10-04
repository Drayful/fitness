<?php

namespace Tests\Feature;

use App\Models\BodySample;
use App\Models\User;
use App\Models\Workout;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AccountTest extends TestCase
{
    use RefreshDatabase;

    /** Signs up through the API and stores one sample and one workout. */
    private function registerWithData(string $email): string
    {
        $token = $this->postJson('/api/auth/register', [
            'name' => 'Athlete',
            'email' => $email,
            'password' => 'password123',
        ])->json('token');
        $this->withToken($token)->postJson('/api/measurements/samples', ['samples' => [
            ['kind' => 'heart_rate', 'measured_at' => now()->subHour()->toIso8601String(), 'value' => 61],
        ]])->assertOk();
        $this->withToken($token)->postJson('/api/workouts', [
            'performed_at' => now()->subDay()->toIso8601String(),
            'type' => 'run',
            'duration_minutes' => 30,
            'intensity' => 5,
        ])->assertCreated();

        return $token;
    }

    /** Another account's data, written directly so only one user is signed in. */
    private function seedOtherUser(): User
    {
        $other = User::factory()->create(['email' => 'other@example.com']);
        BodySample::query()->create([
            'user_id' => $other->id,
            'kind' => 'heart_rate',
            'measured_at' => now()->subHour(),
            'value' => 70,
        ]);
        Workout::query()->create([
            'user_id' => $other->id,
            'performed_at' => now()->subDay(),
            'type' => 'walk',
            'duration_minutes' => 20,
            'intensity' => 3,
        ]);

        return $other;
    }

    public function test_export_contains_only_own_data(): void
    {
        $this->seedOtherUser();
        $mine = $this->registerWithData('me@example.com');

        $this->withToken($mine)->getJson('/api/auth/me/export')
            ->assertOk()
            ->assertJsonPath('format', 'yumn-export-v1')
            ->assertJsonPath('user.email', 'me@example.com')
            ->assertJsonCount(1, 'body_samples')
            ->assertJsonPath('body_samples.0.value', 61)
            ->assertJsonCount(1, 'workouts')
            ->assertJsonPath('workouts.0.type', 'run')
            ->assertJsonMissingPath('body_samples.0.user_id')
            ->assertJsonMissingPath('user.password');
    }

    public function test_delete_requires_password_and_erases_everything(): void
    {
        $other = $this->seedOtherUser();
        $mine = $this->registerWithData('me@example.com');

        $this->withToken($mine)->deleteJson('/api/auth/me', ['password' => 'wrong-password'])
            ->assertUnprocessable();
        $this->assertDatabaseHas('users', ['email' => 'me@example.com']);

        $this->withToken($mine)->deleteJson('/api/auth/me', ['password' => 'password123'])
            ->assertOk()
            ->assertJsonPath('deleted', true);

        $this->assertDatabaseMissing('users', ['email' => 'me@example.com']);
        $this->assertDatabaseCount('personal_access_tokens', 0);
        // The other account is untouched.
        $this->assertDatabaseHas('body_samples', ['user_id' => $other->id]);
        $this->assertDatabaseHas('workouts', ['user_id' => $other->id]);
        $this->assertDatabaseCount('body_samples', 1);
        $this->assertDatabaseCount('workouts', 1);
    }
}
