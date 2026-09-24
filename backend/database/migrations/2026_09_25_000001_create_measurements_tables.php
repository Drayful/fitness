<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('heart_rate_samples', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('client_id', 100);
            $table->timestamp('measured_at');
            $table->unsignedSmallInteger('bpm');
            $table->timestamps();
            $table->unique(['user_id', 'client_id']);
            $table->index(['user_id', 'measured_at']);
        });

        Schema::create('sleep_observations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('client_id', 100);
            $table->timestamp('started_at');
            $table->timestamp('ended_at');
            $table->unsignedSmallInteger('observed_minutes');
            $table->boolean('stages_validated')->default(false);
            $table->timestamps();
            $table->unique(['user_id', 'client_id']);
            $table->index(['user_id', 'ended_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sleep_observations');
        Schema::dropIfExists('heart_rate_samples');
    }
};
