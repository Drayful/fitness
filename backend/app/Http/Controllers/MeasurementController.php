<?php

namespace App\Http\Controllers;

use App\Models\HeartRateSample;
use App\Models\SleepObservation;
use Illuminate\Http\Request;

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

    public function storeSleep(Request $request)
    {
        $data = $request->validate([
            'client_id' => ['required', 'string', 'max:100'],
            'started_at' => ['required', 'date', 'before_or_equal:now'],
            'ended_at' => ['required', 'date', 'after:started_at', 'before_or_equal:now'],
            'observed_minutes' => ['required', 'integer', 'between:1,1440'],
            'stages_validated' => ['required', 'boolean'],
        ]);

        $observation = SleepObservation::query()->firstOrCreate(
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
