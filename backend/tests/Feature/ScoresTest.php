<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ScoresTest extends TestCase
{
    use RefreshDatabase;

    public function test_scores_today_requires_auth(): void
    {
        $this->getJson('/api/scores/today')->assertUnauthorized();
    }

    public function test_scores_today_returns_scores(): void
    {
        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $res = $this->withHeader('Authorization', "Bearer {$token}")
            ->getJson('/api/scores/today');

        $res->assertOk();
        $res->assertJsonStructure([
            'scores' => ['date', 'strain', 'recovery'],
        ]);
    }
}

