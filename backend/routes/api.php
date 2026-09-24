<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\CheckinController;
use App\Http\Controllers\MeasurementController;
use App\Http\Controllers\ScoreController;
use App\Http\Controllers\WorkoutController;
use Illuminate\Support\Facades\Route;

Route::prefix('auth')->group(function () {
    Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:10,1');
    Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:10,1');

    Route::middleware('auth:sanctum')->group(function () {
        Route::post('/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);
    });
});

Route::middleware('auth:sanctum')->group(function () {
    Route::apiResource('workouts', WorkoutController::class)->only(['index', 'store', 'show', 'destroy']);
    Route::post('/checkins/sleep', [CheckinController::class, 'sleep']);
    Route::post('/measurements/heart-rate', [MeasurementController::class, 'storeHeartRate']);
    Route::get('/measurements/heart-rate/recent', [MeasurementController::class, 'recentHeartRate']);
    Route::post('/measurements/sleep', [MeasurementController::class, 'storeSleep']);
    Route::get('/measurements/sleep/recent', [MeasurementController::class, 'recentSleep']);

    Route::get('/scores/today', [ScoreController::class, 'today']);
});
