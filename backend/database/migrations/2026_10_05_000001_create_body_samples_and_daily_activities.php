<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Raw readings downloaded from the band's own memory (TZ §5, §64 RAW
        // DATA): one row per metric and timestamp, so re-syncing the same
        // history overwrites instead of duplicating.
        Schema::create('body_samples', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('kind', 20);
            $table->timestamp('measured_at');
            $table->decimal('value', 7, 2);
            $table->string('device_model', 30)->nullable();
            $table->timestamps();
            $table->unique(['user_id', 'kind', 'measured_at']);
            $table->index(['user_id', 'kind', 'measured_at']);
        });

        // Per-day totals the band keeps (steps, distance, calories, active time).
        Schema::create('daily_activities', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->date('date');
            $table->unsignedInteger('steps')->default(0);
            $table->unsignedInteger('distance_m')->default(0);
            $table->decimal('calories', 8, 2)->default(0);
            $table->unsignedSmallInteger('active_minutes')->default(0);
            $table->string('device_model', 30)->nullable();
            $table->timestamps();
            $table->unique(['user_id', 'date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('daily_activities');
        Schema::dropIfExists('body_samples');
    }
};
