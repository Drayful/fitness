<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('vital_snapshots', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('client_id', 100);
            $table->timestamp('measured_at');
            $table->unsignedSmallInteger('heart_rate')->nullable();
            $table->unsignedSmallInteger('spo2')->nullable();
            $table->decimal('temperature_c', 5, 2)->nullable();
            $table->unsignedInteger('steps')->nullable();
            $table->string('device_model', 30)->nullable();
            $table->timestamps();
            $table->unique(['user_id', 'client_id']);
            $table->index(['user_id', 'measured_at']);
        });

        Schema::table('sleep_observations', function (Blueprint $table) {
            $table->json('records')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('sleep_observations', function (Blueprint $table) {
            $table->dropColumn('records');
        });
        Schema::dropIfExists('vital_snapshots');
    }
};
