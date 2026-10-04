<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BandHistoryTest extends TestCase
{
    use RefreshDatabase;

    public function test_samples_are_batched_idempotent_and_summarised(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');
        $at = now()->subHour()->startOfMinute();
        $body = ['device_model' => 'legacyV8', 'samples' => [
            ['kind' => 'heart_rate', 'measured_at' => $at->toIso8601String(), 'value' => 60],
            ['kind' => 'heart_rate', 'measured_at' => $at->copy()->addMinute()->toIso8601String(), 'value' => 70],
            ['kind' => 'hrv', 'measured_at' => $at->toIso8601String(), 'value' => 48],
            ['kind' => 'temperature', 'measured_at' => $at->toIso8601String(), 'value' => 36.4],
        ]];

        $this->postJson('/api/measurements/samples', $body)->assertOk()->assertJsonPath('stored', 4);
        // A re-sync of the same history overwrites instead of duplicating.
        $body['samples'][1]['value'] = 72;
        $this->postJson('/api/measurements/samples', $body)->assertOk();
        $this->assertDatabaseCount('body_samples', 4);

        $this->getJson('/api/measurements/samples/summary?hours=24')
            ->assertOk()
            ->assertJsonPath('summary.heart_rate.count', 2)
            ->assertJsonPath('summary.heart_rate.latest', 72)
            ->assertJsonPath('summary.heart_rate.min', 60)
            ->assertJsonPath('summary.heart_rate.max', 72)
            ->assertJsonPath('summary.hrv.latest', 48)
            ->assertJsonPath('summary.temperature.latest', 36.4)
            ->assertJsonMissingPath('summary.spo2');
    }

    public function test_samples_reject_implausible_values_and_unknown_kinds(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');
        $at = now()->subMinutes(5)->toIso8601String();

        $this->postJson('/api/measurements/samples', ['samples' => [
            ['kind' => 'spo2', 'measured_at' => $at, 'value' => 140],
        ]])->assertUnprocessable()->assertJsonValidationErrors('samples.0.value');

        $this->postJson('/api/measurements/samples', ['samples' => [
            ['kind' => 'blood_pressure', 'measured_at' => $at, 'value' => 120],
        ]])->assertUnprocessable();

        $this->postJson('/api/measurements/samples', ['samples' => [
            ['kind' => 'heart_rate', 'measured_at' => now()->addDay()->toIso8601String(), 'value' => 70],
        ]])->assertUnprocessable();

        $this->assertDatabaseCount('body_samples', 0);
    }

    public function test_samples_are_private_to_their_owner(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');
        $this->postJson('/api/measurements/samples', ['samples' => [
            ['kind' => 'heart_rate', 'measured_at' => now()->subMinute()->toIso8601String(), 'value' => 80],
        ]])->assertOk();

        $this->actingAs(User::factory()->create(), 'sanctum');
        $this->getJson('/api/measurements/samples/summary')->assertOk()->assertJsonPath('summary', []);
    }

    public function test_calibration_counts_distinct_days_with_data(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');
        $this->getJson('/api/measurements/calibration')
            ->assertOk()
            ->assertJsonPath('days_with_data', 0)
            ->assertJsonPath('target_days', 21)
            ->assertJsonPath('complete', false);

        $d1 = now()->subDays(3)->setTime(10, 0);
        $d2 = now()->subDays(1)->setTime(10, 0);
        $this->postJson('/api/measurements/samples', ['samples' => [
            ['kind' => 'heart_rate', 'measured_at' => $d1->toIso8601String(), 'value' => 60],
            ['kind' => 'heart_rate', 'measured_at' => $d1->copy()->addHour()->toIso8601String(), 'value' => 62],
            ['kind' => 'spo2', 'measured_at' => $d2->toIso8601String(), 'value' => 97],
        ]])->assertOk();
        $this->postJson('/api/measurements/vitals', [
            'client_id' => 'v-1',
            'measured_at' => $d2->toIso8601String(),
            'heart_rate' => 70,
        ])->assertCreated();

        $this->getJson('/api/measurements/calibration')
            ->assertOk()
            ->assertJsonPath('days_with_data', 2)
            ->assertJsonPath('first_day', $d1->copy()->utc()->toDateString());
    }

    public function test_resting_heart_rate_uses_lowest_tenth_and_needs_enough_readings(): void
    {
        // Midday UTC, so "today" readings are never in the future.
        $this->travelTo(now()->utc()->setTime(12, 0));
        $this->actingAs(User::factory()->create(), 'sanctum');
        $start = now()->utc()->startOfDay()->addMinutes(5);
        // 30 readings today: three at 50 (the lowest 10 %), the rest at 80.
        $samples = [];
        for ($i = 0; $i < 30; $i++) {
            $samples[] = [
                'kind' => 'heart_rate',
                'measured_at' => $start->copy()->addMinutes($i)->toIso8601String(),
                'value' => $i < 3 ? 50 : 80,
            ];
        }
        // Yesterday: only 5 readings — not enough for a value.
        for ($i = 0; $i < 5; $i++) {
            $samples[] = [
                'kind' => 'heart_rate',
                'measured_at' => $start->copy()->subDay()->addMinutes($i)->toIso8601String(),
                'value' => 40,
            ];
        }
        $this->postJson('/api/measurements/samples', ['samples' => $samples])->assertOk();

        $this->getJson('/api/measurements/resting-heart-rate')
            ->assertOk()
            ->assertJsonPath('algorithm', 'rhr-v1')
            ->assertJsonPath('today', 50)
            ->assertJsonCount(1, 'days')
            ->assertJsonPath('baseline', null);
    }

    public function test_daily_activity_upserts_per_day(): void
    {
        $this->actingAs(User::factory()->create(), 'sanctum');
        $day = ['date' => now()->toDateString(), 'steps' => 4200, 'distance_m' => 3100, 'calories' => 180.5, 'active_minutes' => 35];

        $this->postJson('/api/activity/daily', ['days' => [$day]])->assertOk()->assertJsonPath('stored', 1);
        $day['steps'] = 5100;
        $this->postJson('/api/activity/daily', ['days' => [$day]])->assertOk();
        $this->assertDatabaseCount('daily_activities', 1);

        $this->getJson('/api/activity/daily/recent')
            ->assertOk()
            ->assertJsonPath('days.0.steps', 5100)
            ->assertJsonPath('days.0.date', now()->toDateString());

        $this->postJson('/api/activity/daily', ['days' => [array_merge($day, ['steps' => -1])]])
            ->assertUnprocessable();
    }
}
