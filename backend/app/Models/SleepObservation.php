<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['user_id', 'client_id', 'started_at', 'ended_at', 'observed_minutes', 'stages_validated'])]
class SleepObservation extends Model
{
    protected function casts(): array
    {
        return [
            'started_at' => 'datetime',
            'ended_at' => 'datetime',
            'observed_minutes' => 'integer',
            'stages_validated' => 'boolean',
        ];
    }
}
