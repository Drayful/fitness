<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['user_id', 'client_id', 'measured_at', 'heart_rate', 'spo2', 'temperature_c', 'steps', 'device_model'])]
class VitalSnapshot extends Model
{
    protected function casts(): array
    {
        return [
            'measured_at' => 'datetime',
            'heart_rate' => 'integer',
            'spo2' => 'integer',
            'temperature_c' => 'float',
            'steps' => 'integer',
        ];
    }
}
