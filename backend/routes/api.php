<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\BandHistoryController;
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
        Route::patch('/me', [AuthController::class, 'updateProfile']);
    });
});

Route::middleware('auth:sanctum')->group(function () {
    Route::apiResource('workouts', WorkoutController::class)->only(['index', 'store', 'show', 'destroy']);
    Route::post('/checkins/sleep', [CheckinController::class, 'sleep']);
    Route::post('/measurements/heart-rate', [MeasurementController::class, 'storeHeartRate']);
    Route::get('/measurements/heart-rate/recent', [MeasurementController::class, 'recentHeartRate']);
    Route::post('/measurements/vitals', [MeasurementController::class, 'storeVitals']);
    Route::get('/measurements/vitals/recent', [MeasurementController::class, 'recentVitals']);
    Route::post('/measurements/sleep', [MeasurementController::class, 'storeSleep']);
    Route::get('/measurements/sleep/recent', [MeasurementController::class, 'recentSleep']);
    Route::post('/measurements/samples', [BandHistoryController::class, 'storeSamples']);
    Route::get('/measurements/samples/summary', [BandHistoryController::class, 'sampleSummary']);
    Route::get('/measurements/calibration', [BandHistoryController::class, 'calibration']);
    Route::post('/activity/daily', [BandHistoryController::class, 'storeDailyActivity']);
    Route::get('/activity/daily/recent', [BandHistoryController::class, 'recentDailyActivity']);

    Route::get('/scores/today', [ScoreController::class, 'today']);
});
