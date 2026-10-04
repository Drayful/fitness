<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['user_id', 'kind', 'measured_at', 'value', 'device_model'])]
class BodySample extends Model
{
    /** Accepted kinds and their plausible value ranges. */
    public const RANGES = [
        'heart_rate' => [30, 240],
        'hrv' => [1, 300],
        'spo2' => [70, 100],
        'temperature' => [25, 45],
        'stress' => [0, 100],
    ];

    protected function casts(): array
    {
        return ['measured_at' => 'datetime', 'value' => 'float'];
    }
}
