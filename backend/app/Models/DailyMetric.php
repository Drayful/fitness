<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'user_id',
    'date',
    'sleep_hours',
    'sleep_quality',
])]
class DailyMetric extends Model
{
    public $timestamps = true;

    protected function casts(): array
    {
        return [
            'date' => 'date',
            'sleep_hours' => 'float',
            'sleep_quality' => 'float',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}

