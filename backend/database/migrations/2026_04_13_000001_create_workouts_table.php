<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('workouts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->dateTime('performed_at');
            $table->string('type', 50);
            $table->unsignedSmallInteger('duration_minutes');
            $table->unsignedTinyInteger('intensity'); // 1..10
            $table->string('notes', 1000)->nullable();
            $table->timestamps();

            $table->index(['user_id', 'performed_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('workouts');
    }
};

