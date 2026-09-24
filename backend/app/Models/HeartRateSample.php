<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['user_id', 'client_id', 'measured_at', 'bpm'])]
class HeartRateSample extends Model
{
    protected function casts(): array
    {
        return ['measured_at' => 'datetime', 'bpm' => 'integer'];
    }
}
