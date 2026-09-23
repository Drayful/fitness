<?php

namespace App\Http\Controllers;

use App\Models\Workout;
use Illuminate\Http\Request;

class WorkoutController extends Controller
{
    public function index(Request $request)
    {
        $workouts = Workout::query()
            ->where('user_id', $request->user()->id)
            ->orderByDesc('performed_at')
            ->paginate(50);

        return response()->json($workouts);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'performed_at' => ['required', 'date'],
            'type' => ['required', 'string', 'max:50'],
            'duration_minutes' => ['required', 'integer', 'min:1', 'max:600'],
            'intensity' => ['required', 'integer', 'min:1', 'max:10'],
            'notes' => ['nullable', 'string', 'max:1000'],
            'client_id' => ['nullable', 'string', 'max:100'],
            'metrics' => ['nullable', 'array:steps,calories,distance_m,last_heart_rate,duration_seconds'],
            'metrics.steps' => ['nullable', 'integer', 'min:0'],
            'metrics.calories' => ['nullable', 'numeric', 'min:0'],
            'metrics.distance_m' => ['nullable', 'numeric', 'min:0'],
            'metrics.last_heart_rate' => ['nullable', 'integer', 'min:1', 'max:255'],
            'metrics.duration_seconds' => ['nullable', 'integer', 'min:0'],
        ]);

        if (! empty($data['client_id'])) {
            $workout = Workout::query()->firstOrCreate(
                ['user_id' => $request->user()->id, 'client_id' => $data['client_id']],
                $data,
            );
        } else {
            $workout = Workout::create(['user_id' => $request->user()->id, ...$data]);
        }

        return response()->json(['workout' => $workout], $workout->wasRecentlyCreated ? 201 : 200);
    }

    public function show(Request $request, Workout $workout)
    {
        if ($workout->user_id !== $request->user()->id) {
            abort(404);
        }

        return response()->json(['workout' => $workout]);
    }

    public function destroy(Request $request, Workout $workout)
    {
        if ($workout->user_id !== $request->user()->id) {
            abort(404);
        }

        $workout->delete();

        return response()->json(['ok' => true]);
    }
}
