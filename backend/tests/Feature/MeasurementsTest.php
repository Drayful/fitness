<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MeasurementsTest extends TestCase
{
    use RefreshDatabase;

    public function test_heart_rate_samples_are_private_idempotent_and_average_last_ten(): void
    {
        $this->getJson('/api/measurements/heart-rate/recent')->assertUnauthorized();
        $owner = User::factory()->create();
        $this->actingAs($owner, 'sanctum');
        for ($i = 1; $i <= 11; $i++) {
            $body = ['client_id' => 'hr-'.$i, 'measured_at' => sprintf('2026-09-18T10:%02d:00Z', $i), 'bpm' => 60 + $i];
            $this->postJson('/api/measurements/heart-rate', $body)->assertCreated();
        }
        $this->postJson('/api/measurements/heart-rate', ['client_id' => 'hr-11', 'measured_at' => '2026-09-18T10:11:00Z', 'bpm' => 200])->assertOk();
        $this->getJson('/api/measurements/heart-rate/recent')->assertOk()
            ->assertJsonPath('count', 10)
            ->assertJsonPath('average_bpm', 66.5)
            ->assertJsonPath('samples.0.bpm', 71);
        $this->assertDatabaseCount('heart_rate_samples', 11);

        $this->actingAs(User::factory()->create(), 'sanctum');
        $this->getJson('/api/measurements/heart-rate/recent')->assertJsonPath('count', 0);
        $this->postJson('/api/measurements/heart-rate', ['client_id' => 'hr-1', 'measured_at' => '2026-09-18T10:01:00Z', 'bpm' => 90])->assertCreated();
        $this->postJson('/api/measurements/heart-rate', ['client_id' => 'bad', 'measured_at' => '2026-09-18T10:01:00Z', 'bpm' => 0])->assertUnprocessable();
    }

    public function test_unverified_sleep_interval_is_saved_without_inventing_sleep_metric(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');
        $body = [
            'client_id' => 'sleep-1',
            'started_at' => '2026-09-17T22:00:00Z',
            'ended_at' => '2026-09-18T06:00:00Z',
            'observed_minutes' => 420,
            'stages_validated' => false,
        ];
        $this->postJson('/api/measurements/sleep', $body)->assertCreated();
        $this->postJson('/api/measurements/sleep', $body)->assertOk();
        $this->getJson('/api/measurements/sleep/recent')->assertOk()
            ->assertJsonPath('observations.0.observed_minutes', 420)
            ->assertJsonPath('observations.0.stages_validated', false);
        $this->assertDatabaseCount('sleep_observations', 1);
        $this->assertDatabaseCount('daily_metrics', 0);

        $this->postJson('/api/measurements/sleep', [
            ...$body,
            'client_id' => 'invalid',
            'ended_at' => '2026-09-17T21:00:00Z',
        ])->assertUnprocessable();
    }
}
