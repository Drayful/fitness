<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Body profile: sent to the band for calorie/distance estimates and
        // used for age-based heart-rate zones. All optional.
        Schema::table('users', function (Blueprint $table) {
            $table->string('sex', 10)->nullable();
            $table->date('birth_date')->nullable();
            $table->unsignedSmallInteger('height_cm')->nullable();
            $table->decimal('weight_kg', 5, 1)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['sex', 'birth_date', 'height_cm', 'weight_kg']);
        });
    }
};
