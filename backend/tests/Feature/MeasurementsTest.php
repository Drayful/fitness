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

    public function test_vital_snapshots_save_available_fields_without_cross_account_access(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');
        $body = [
            'client_id' => 'vitals-1',
            'measured_at' => '2026-09-18T10:00:00Z',
            'heart_rate' => 72,
            'spo2' => 98,
            'temperature_c' => 36.4,
            'steps' => 1234,
            'device_model' => 'jc2208a',
        ];
        $this->postJson('/api/measurements/vitals', $body)->assertCreated()
            ->assertJsonPath('snapshot.spo2', 98)
            ->assertJsonPath('snapshot.steps', 1234);
        $this->postJson('/api/measurements/vitals', [...$body, 'heart_rate' => 99])->assertOk();
        $this->getJson('/api/measurements/vitals/recent')->assertJsonCount(1, 'snapshots');
        $this->getJson('/api/measurements/heart-rate/recent')->assertJsonPath('average_bpm', 72);
        $this->assertDatabaseCount('vital_snapshots', 1);
        $this->assertDatabaseCount('heart_rate_samples', 1);

        $this->postJson('/api/measurements/vitals', [
            'client_id' => 'vitals-2',
            'measured_at' => '2026-09-18T10:01:00Z',
            'heart_rate' => null,
            'spo2' => 97,
        ])->assertCreated();
        $this->assertDatabaseCount('heart_rate_samples', 1);
        $this->postJson('/api/measurements/vitals', [
            'client_id' => 'empty', 'measured_at' => '2026-09-18T10:02:00Z',
        ])->assertUnprocessable();

        $this->actingAs(User::factory()->create(), 'sanctum');
        $this->getJson('/api/measurements/vitals/recent')->assertJsonCount(0, 'snapshots');
        $this->postJson('/api/measurements/vitals', $body)->assertCreated();
    }

    public function test_raw_sleep_records_are_kept_for_later_interpretation(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');
        $body = [
            'client_id' => 'raw-sleep-1',
            'started_at' => '2026-09-17T22:00:00Z',
            'ended_at' => '2026-09-18T06:00:00Z',
            'observed_minutes' => 120,
            'stages_validated' => false,
            'records' => [[
                'start_at' => '2026-09-17T22:00:00Z',
                'unit_minutes' => 5,
                'raw_values' => [0, 1, 255],
            ]],
        ];
        $this->postJson('/api/measurements/sleep', $body)->assertCreated();
        $this->postJson('/api/measurements/sleep', $body)->assertOk();
        $this->getJson('/api/measurements/sleep/recent')
            ->assertJsonPath('observations.0.records.0.raw_values.2', 255);
        $this->assertDatabaseCount('sleep_observations', 1);
        $this->assertDatabaseCount('daily_metrics', 0);
    }
}
