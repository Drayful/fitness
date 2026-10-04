<?php

namespace App\Http\Controllers;

use App\Models\BodySample;
use App\Models\DailyActivity;
use App\Models\DailyMetric;
use App\Models\HeartRateSample;
use App\Models\SleepObservation;
use App\Models\VitalSnapshot;
use App\Models\Workout;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

/**
 * TZ §57: the user can export everything stored about them and delete the
 * account. Both only ever touch the authenticated user's own rows.
 */
class AccountController extends Controller
{
    /** Tables holding personal data, exported and erased together. */
    private const DATA = [
        'workouts' => Workout::class,
        'daily_metrics' => DailyMetric::class,
        'heart_rate_samples' => HeartRateSample::class,
        'vital_snapshots' => VitalSnapshot::class,
        'sleep_observations' => SleepObservation::class,
        'body_samples' => BodySample::class,
        'daily_activities' => DailyActivity::class,
    ];

    public function export(Request $request)
    {
        $user = $request->user();
        $export = [
            'format' => 'yumn-export-v1',
            'exported_at' => now()->toIso8601String(),
            'user' => $user->only(['name', 'email', 'sex', 'birth_date', 'height_cm', 'weight_kg', 'created_at']),
        ];
        foreach (self::DATA as $key => $model) {
            $export[$key] = $model::query()
                ->where('user_id', $user->id)
                ->orderBy('id')
                ->get()
                ->map(fn ($row) => collect($row->toArray())->except(['user_id'])->all())
                ->all();
        }

        return response()->json($export);
    }

    /** Permanent; requires the current password as confirmation. */
    public function destroy(Request $request)
    {
        $data = $request->validate([
            'password' => ['required', 'string', 'max:72'],
        ]);
        $user = $request->user();
        if (! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages(['password' => ['Incorrect password.']]);
        }

        DB::transaction(function () use ($user) {
            foreach (self::DATA as $model) {
                $model::query()->where('user_id', $user->id)->delete();
            }
            $user->tokens()->delete();
            $user->delete();
        });

        return response()->json(['deleted' => true]);
    }
}
