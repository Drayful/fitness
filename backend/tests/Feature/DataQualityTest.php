<?php

namespace Tests\Feature;

use App\Models\DailyMetric;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DataQualityTest extends TestCase
{
    use RefreshDatabase;

    public function test_missing_sleep_is_not_reported_as_low_recovery(): void
    {
        $user = User::factory()->create();
        $this->actingAs($user, 'sanctum')->getJson('/api/scores/today')
            ->assertOk()->assertJsonPath('scores.recovery', null)
            ->assertJsonPath('scores.status', 'insufficient_data')
            ->assertJsonPath('scores.validated', false);
    }

    public function test_null_sleep_quality_uses_default_and_retries_update_one_record(): void
    {
        $user = User::factory()->create();
        $this->actingAs($user, 'sanctum');
        for ($i = 0; $i < 2; $i++) {
            $this->postJson('/api/checkins/sleep', ['date' => '2026-09-18', 'sleep_hours' => 8, 'sleep_quality' => null])->assertCreated();
        }
        $this->assertDatabaseCount('daily_metrics', 1);
        $this->assertEquals(0.5, DailyMetric::first()->sleep_quality);
    }

    public function test_cannot_read_or_delete_another_users_workout(): void
    {
        $owner = User::factory()->create();
        $this->actingAs($owner, 'sanctum');
        $id = $this->postJson('/api/workouts', ['performed_at' => '2026-09-18T10:00:00Z', 'type' => 'run', 'duration_minutes' => 30, 'intensity' => 5])->assertCreated()->json('workout.id');
        $this->actingAs(User::factory()->create(), 'sanctum');
        $this->getJson('/api/workouts/'.$id)->assertNotFound();
        $this->deleteJson('/api/workouts/'.$id)->assertNotFound();
        $this->assertDatabaseCount('workouts', 1);
    }

    public function test_login_is_rate_limited(): void
    {
        for ($i = 0; $i < 10; $i++) {
            $this->postJson('/api/auth/login', ['email' => 'absent@example.com', 'password' => 'incorrect'])->assertUnprocessable();
        }
        $this->postJson('/api/auth/login', ['email' => 'absent@example.com', 'password' => 'incorrect'])->assertTooManyRequests();
    }

    public function test_workout_retry_is_idempotent_and_keeps_structured_metrics(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');
        $body = ['client_id' => 'run-123', 'performed_at' => '2026-09-18T10:00:00Z', 'type' => 'run', 'duration_minutes' => 30, 'intensity' => 5,
            'metrics' => ['steps' => 1000, 'duration_seconds' => 1800, 'last_heart_rate' => null, 'distance_m' => null]];
        $id = $this->postJson('/api/workouts', $body)->assertCreated()->json('workout.id');
        $this->postJson('/api/workouts', $body)->assertOk()->assertJsonPath('workout.id', $id)->assertJsonPath('workout.metrics.steps', 1000);
        $this->assertDatabaseCount('workouts', 1);
        $this->actingAs(User::factory()->create(), 'sanctum');
        $this->postJson('/api/workouts', $body)->assertCreated();
        $this->assertDatabaseCount('workouts', 2);
    }

    public function test_workout_keeps_heart_rate_samples_and_rejects_bad_ones(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');
        $body = ['client_id' => 'run-hr', 'performed_at' => '2026-10-04T10:00:00Z', 'type' => 'run', 'duration_minutes' => 1, 'intensity' => 5,
            'metrics' => ['heart_rate_samples' => [92, 110, 131], 'heart_rate_sample_seconds' => 5]];
        $this->postJson('/api/workouts', $body)->assertCreated()
            ->assertJsonPath('workout.metrics.heart_rate_samples', [92, 110, 131])
            ->assertJsonPath('workout.metrics.heart_rate_sample_seconds', 5);

        $bad = $body;
        $bad['client_id'] = 'run-hr-bad';
        $bad['metrics']['heart_rate_samples'] = [92, 400];
        $this->postJson('/api/workouts', $bad)->assertUnprocessable();

        $noInterval = $body;
        $noInterval['client_id'] = 'run-hr-nointerval';
        unset($noInterval['metrics']['heart_rate_sample_seconds']);
        $this->postJson('/api/workouts', $noInterval)->assertUnprocessable();
    }

    public function test_passwords_exceeding_bcrypt_byte_limit_are_validation_errors(): void
    {
        foreach ([str_repeat('я', 40), "password\0invalid"] as $password) {
            $body = ['name' => 'Test', 'email' => 'length@example.com', 'password' => $password];
            $this->postJson('/api/auth/register', $body)->assertUnprocessable()->assertJsonValidationErrors('password');
            $this->postJson('/api/auth/login', $body)->assertUnprocessable()->assertJsonValidationErrors('password');
        }
        $this->assertDatabaseCount('users', 0);
    }
}
