<?php

namespace App\Http\Controllers;

use App\Models\HeartRateSample;
use App\Models\SleepObservation;
use App\Models\VitalSnapshot;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class MeasurementController extends Controller
{
    public function storeHeartRate(Request $request)
    {
        $data = $request->validate([
            'client_id' => ['required', 'string', 'max:100'],
            'measured_at' => ['required', 'date', 'before_or_equal:now'],
            'bpm' => ['required', 'integer', 'between:30,240'],
        ]);

        $sample = HeartRateSample::query()->firstOrCreate(
            ['user_id' => $request->user()->id, 'client_id' => $data['client_id']],
            $data,
        );

        return response()->json(['sample' => $sample], $sample->wasRecentlyCreated ? 201 : 200);
    }

    public function recentHeartRate(Request $request)
    {
        $samples = HeartRateSample::query()
            ->where('user_id', $request->user()->id)
            ->orderByDesc('measured_at')
            ->orderByDesc('id')
            ->limit(10)
            ->get();

        return response()->json([
            'samples' => $samples,
            'count' => $samples->count(),
            'average_bpm' => $samples->isEmpty() ? null : round($samples->avg('bpm'), 1),
        ]);
    }

    public function storeVitals(Request $request)
    {
        $data = $request->validate([
            'client_id' => ['required', 'string', 'max:100'],
            'measured_at' => ['required', 'date', 'before_or_equal:now'],
            'heart_rate' => ['nullable', 'integer', 'between:30,240'],
            'spo2' => ['nullable', 'integer', 'between:1,100'],
            'temperature_c' => ['nullable', 'numeric', 'between:0,60'],
            'steps' => ['nullable', 'integer', 'between:0,1000000'],
            'device_model' => ['nullable', 'in:legacyV8,jc2208a'],
        ]);

        if (collect(['heart_rate', 'spo2', 'temperature_c', 'steps'])
            ->every(fn ($field) => ($data[$field] ?? null) === null)) {
            throw ValidationException::withMessages(['measurements' => 'At least one measurement is required.']);
        }

        $snapshot = DB::transaction(function () use ($request, $data) {
            $snapshot = VitalSnapshot::query()->firstOrCreate(
                ['user_id' => $request->user()->id, 'client_id' => $data['client_id']],
                $data,
            );
            if ($snapshot->heart_rate !== null) {
                HeartRateSample::query()->firstOrCreate(
                    ['user_id' => $request->user()->id, 'client_id' => $data['client_id']],
                    ['measured_at' => $snapshot->measured_at, 'bpm' => $snapshot->heart_rate],
                );
            }

            return $snapshot;
        });

        return response()->json(['snapshot' => $snapshot], $snapshot->wasRecentlyCreated ? 201 : 200);
    }

    public function recentVitals(Request $request)
    {
        return response()->json([
            'snapshots' => VitalSnapshot::query()
                ->where('user_id', $request->user()->id)
                ->orderByDesc('measured_at')
                ->orderByDesc('id')
                ->limit(50)
                ->get(),
        ]);
    }

    public function storeSleep(Request $request)
    {
        $data = $request->validate([
            'client_id' => ['required', 'string', 'max:100'],
            'started_at' => ['required', 'date', 'before_or_equal:now'],
            'ended_at' => ['required', 'date', 'after:started_at', 'before_or_equal:now'],
            'observed_minutes' => ['required', 'integer', 'between:1,1440'],
            'stages_validated' => ['required', 'boolean'],
            'records' => ['nullable', 'array', 'max:100'],
            'records.*' => ['required', 'array:start_at,unit_minutes,raw_values'],
            'records.*.start_at' => ['required', 'date'],
            'records.*.unit_minutes' => ['required', 'integer', 'in:1,5'],
            'records.*.raw_values' => ['required', 'array', 'max:120'],
            'records.*.raw_values.*' => ['required', 'integer', 'between:0,255'],
        ]);

        $observation = SleepObservation::query()->updateOrCreate(
            ['user_id' => $request->user()->id, 'client_id' => $data['client_id']],
            $data,
        );

        return response()->json(['observation' => $observation], $observation->wasRecentlyCreated ? 201 : 200);
    }

    public function recentSleep(Request $request)
    {
        return response()->json([
            'observations' => SleepObservation::query()
                ->where('user_id', $request->user()->id)
                ->orderByDesc('ended_at')
                ->limit(20)
                ->get(),
        ]);
    }
}
