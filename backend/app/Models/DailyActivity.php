<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['user_id', 'date', 'steps', 'distance_m', 'calories', 'active_minutes', 'device_model'])]
class DailyActivity extends Model
{
    protected function casts(): array
    {
        return [
            'date' => 'date:Y-m-d',
            'steps' => 'integer',
            'distance_m' => 'integer',
            'calories' => 'float',
            'active_minutes' => 'integer',
        ];
    }
}
