<?php

namespace App\Http\Controllers;

use App\Models\BodySample;
use App\Models\DailyActivity;
use App\Models\SleepObservation;
use App\Models\VitalSnapshot;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/**
 * History downloaded from the band's own memory (TZ §5): batched raw
 * readings and per-day activity totals. Uploads are idempotent — the same
 * history can be re-synced without creating duplicates.
 */
class BandHistoryController extends Controller
{
    public function storeSamples(Request $request)
    {
        $data = $request->validate([
            'device_model' => ['nullable', 'in:legacyV8,jc2208a'],
            'samples' => ['required', 'array', 'min:1', 'max:2000'],
            'samples.*.kind' => ['required', Rule::in(array_keys(BodySample::RANGES))],
            'samples.*.measured_at' => ['required', 'date', 'before_or_equal:+10 minutes'],
            'samples.*.value' => ['required', 'numeric'],
        ]);

        $errors = [];
        foreach ($data['samples'] as $i => $sample) {
            [$min, $max] = BodySample::RANGES[$sample['kind']];
            if ($sample['value'] < $min || $sample['value'] > $max) {
                $errors["samples.$i.value"] = "Value is outside the plausible range for {$sample['kind']}.";
            }
        }
        if ($errors) {
            throw ValidationException::withMessages($errors);
        }

        $userId = $request->user()->id;
        $now = now();
        $rows = collect($data['samples'])
            ->map(fn ($s) => [
                'user_id' => $userId,
                'kind' => $s['kind'],
                'measured_at' => Carbon::parse($s['measured_at'])->utc()->format('Y-m-d H:i:s'),
                'value' => round((float) $s['value'], 2),
                'device_model' => $data['device_model'] ?? null,
                'created_at' => $now,
                'updated_at' => $now,
            ])
            // Keep the last value when one batch repeats a timestamp.
            ->keyBy(fn ($r) => $r['kind'].'|'.$r['measured_at'])
            ->values()
            ->all();

        foreach (array_chunk($rows, 500) as $chunk) {
            BodySample::query()->upsert(
                $chunk,
                ['user_id', 'kind', 'measured_at'],
                ['value', 'device_model', 'updated_at'],
            );
        }

        return response()->json(['stored' => count($rows)]);
    }

    /** Latest value plus average / min / max per kind over the last N hours. */
    public function sampleSummary(Request $request)
    {
        $data = $request->validate(['hours' => ['nullable', 'integer', 'between:1,720']]);
        $since = now()->subHours($data['hours'] ?? 24);
        $userId = $request->user()->id;

        $summary = [];
        foreach (array_keys(BodySample::RANGES) as $kind) {
            $window = BodySample::query()
                ->where('user_id', $userId)
                ->where('kind', $kind)
                ->where('measured_at', '>=', $since);
            $count = (clone $window)->count();
            if ($count === 0) {
                continue;
            }
            $latest = (clone $window)->orderByDesc('measured_at')->first();
            $summary[$kind] = [
                'count' => $count,
                'latest' => $latest->value,
                'latest_at' => $latest->measured_at->toIso8601String(),
                'average' => round((float) (clone $window)->avg('value'), 1),
                'min' => (float) (clone $window)->min('value'),
                'max' => (float) (clone $window)->max('value'),
            ];
        }

        return response()->json(['since' => $since->toIso8601String(), 'summary' => $summary]);
    }

    /**
     * TZ §6: the personal baseline needs 7–21 days of wear. Counts distinct
     * days with any band data (history samples, live snapshots, sleep).
     */
    public function calibration(Request $request)
    {
        $userId = $request->user()->id;
        $days = collect()
            ->merge(BodySample::query()->where('user_id', $userId)
                ->selectRaw('DATE(measured_at) as d')->distinct()->pluck('d'))
            ->merge(VitalSnapshot::query()->where('user_id', $userId)
                ->selectRaw('DATE(measured_at) as d')->distinct()->pluck('d'))
            ->merge(SleepObservation::query()->where('user_id', $userId)
                ->selectRaw('DATE(ended_at) as d')->distinct()->pluck('d'))
            ->map(fn ($d) => substr((string) $d, 0, 10))
            ->unique()
            ->sort()
            ->values();

        return response()->json([
            'days_with_data' => $days->count(),
            'target_days' => self::CALIBRATION_DAYS,
            'first_day' => $days->first(),
            'complete' => $days->count() >= self::CALIBRATION_DAYS,
        ]);
    }

    public const CALIBRATION_DAYS = 21;

    public function storeDailyActivity(Request $request)
    {
        $data = $request->validate([
            'device_model' => ['nullable', 'in:legacyV8,jc2208a'],
            'days' => ['required', 'array', 'min:1', 'max:60'],
            'days.*.date' => ['required', 'date_format:Y-m-d', 'before_or_equal:tomorrow'],
            'days.*.steps' => ['required', 'integer', 'between:0,200000'],
            'days.*.distance_m' => ['required', 'integer', 'between:0,500000'],
            'days.*.calories' => ['required', 'numeric', 'between:0,20000'],
            'days.*.active_minutes' => ['required', 'integer', 'between:0,1440'],
        ]);

        $userId = $request->user()->id;
        $now = now();
        $rows = collect($data['days'])
            ->map(fn ($d) => [
                'user_id' => $userId,
                'date' => $d['date'],
                'steps' => $d['steps'],
                'distance_m' => $d['distance_m'],
                'calories' => round((float) $d['calories'], 2),
                'active_minutes' => $d['active_minutes'],
                'device_model' => $data['device_model'] ?? null,
                'created_at' => $now,
                'updated_at' => $now,
            ])
            ->keyBy('date')
            ->values()
            ->all();

        DailyActivity::query()->upsert(
            $rows,
            ['user_id', 'date'],
            ['steps', 'distance_m', 'calories', 'active_minutes', 'device_model', 'updated_at'],
        );

        return response()->json(['stored' => count($rows)]);
    }

    public function recentDailyActivity(Request $request)
    {
        return response()->json([
            'days' => DailyActivity::query()
                ->where('user_id', $request->user()->id)
                ->orderByDesc('date')
                ->limit(30)
                ->get(),
        ]);
    }
}
