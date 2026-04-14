<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\CheckinController;
use App\Http\Controllers\ScoreController;
use App\Http\Controllers\WorkoutController;
use Illuminate\Support\Facades\Route;

Route::prefix('auth')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);
    });
});

Route::middleware('auth:sanctum')->group(function () {
    Route::apiResource('workouts', WorkoutController::class)->only(['index', 'store', 'show', 'destroy']);
    Route::post('/checkins/sleep', [CheckinController::class, 'sleep']);

    Route::get('/scores/today', [ScoreController::class, 'today']);
});

