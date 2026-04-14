<?php

namespace App\Services;

use App\Models\DailyMetric;
use App\Models\User;
use App\Models\Workout;
use Carbon\CarbonImmutable;

class ScoreService
{
    public function getTodayScores(User $user, ?CarbonImmutable $today = null): array
    {
        $today = $today ?? CarbonImmutable::today();

        $strain = $this->calculateStrainForDate($user, $today);
        $recovery = $this->calculateRecoveryForDate($user, $today, $strain);

        return [
            'date' => $today->toDateString(),
            'strain' => $strain,
            'recovery' => $recovery,
        ];
    }

    private function calculateStrainForDate(User $user, CarbonImmutable $date): float
    {
        $start = $date->startOfDay();
        $end = $date->endOfDay();

        $load = Workout::query()
            ->where('user_id', $user->id)
            ->whereBetween('performed_at', [$start, $end])
            ->get(['duration_minutes', 'intensity'])
            ->reduce(fn (int $sum, Workout $w) => $sum + ($w->duration_minutes * $w->intensity), 0);

        // Простая шкала 0..21: чем больше нагрузка, тем выше strain.
        $strain = round(min(21, $load / 50), 1);

        return (float) $strain;
    }

    private function calculateRecoveryForDate(User $user, CarbonImmutable $date, float $todayStrain): int
    {
        $metric = DailyMetric::query()
            ->where('user_id', $user->id)
            ->whereDate('date', $date->toDateString())
            ->first();

        $sleepHours = (float) ($metric?->sleep_hours ?? 0);
        $sleepQuality = (float) ($metric?->sleep_quality ?? 0.5);

        $sleepQuality = max(0.0, min(1.0, $sleepQuality));

        $sleepScore = (($sleepHours / 8.0) * 70.0) + ($sleepQuality * 30.0);
        $sleepScore = max(0.0, min(100.0, $sleepScore));

        $yesterday = $date->subDay();
        $yStrain = $this->calculateStrainForDate($user, $yesterday);

        // На практике формула будет сложнее; здесь простой старт: сон минус штраф за вчерашнюю нагрузку.
        $recovery = (int) round($sleepScore - ($yStrain * 2.0) - ($todayStrain * 0.25));

        return max(0, min(100, $recovery));
    }
}

