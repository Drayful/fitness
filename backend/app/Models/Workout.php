<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'user_id',
    'performed_at',
    'type',
    'duration_minutes',
    'intensity',
    'notes',
    'client_id',
    'metrics',
])]
class Workout extends Model
{
    protected function casts(): array
    {
        return [
            'performed_at' => 'datetime',
            'duration_minutes' => 'integer',
            'intensity' => 'integer',
            'metrics' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
