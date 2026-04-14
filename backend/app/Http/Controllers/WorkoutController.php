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
        ]);

        $workout = Workout::create([
            'user_id' => $request->user()->id,
            ...$data,
        ]);

        return response()->json(['workout' => $workout], 201);
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

