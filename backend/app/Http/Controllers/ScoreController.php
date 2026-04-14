<?php

namespace App\Http\Controllers;

use App\Services\ScoreService;
use Illuminate\Http\Request;

class ScoreController extends Controller
{
    public function __construct(private readonly ScoreService $scores)
    {
    }

    public function today(Request $request)
    {
        return response()->json([
            'scores' => $this->scores->getTodayScores($request->user()),
        ]);
    }
}

