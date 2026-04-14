<?php

namespace App\Http\Controllers;

use App\Models\DailyMetric;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;

class CheckinController extends Controller
{
    public function sleep(Request $request)
    {
        $data = $request->validate([
            'date' => ['nullable', 'date'],
            'sleep_hours' => ['required', 'numeric', 'min:0', 'max:24'],
            'sleep_quality' => ['nullable', 'numeric', 'min:0', 'max:1'],
        ]);

        $date = CarbonImmutable::parse($data['date'] ?? CarbonImmutable::today()->toDateString())->toDateString();

        $metric = DailyMetric::query()->updateOrCreate(
            ['user_id' => $request->user()->id, 'date' => $date],
            [
                'sleep_hours' => (float) $data['sleep_hours'],
                'sleep_quality' => array_key_exists('sleep_quality', $data) ? (float) $data['sleep_quality'] : 0.5,
            ]
        );

        return response()->json(['daily_metric' => $metric], 201);
    }
}

