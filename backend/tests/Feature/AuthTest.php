<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_register_returns_token(): void
    {
        $res = $this->postJson('/api/auth/register', [
            'name' => 'Test',
            'email' => 'test@example.com',
            'password' => 'password123',
        ]);

        $res->assertCreated();
        $res->assertJsonStructure([
            'user' => ['id', 'name', 'email'],
            'token',
        ]);
    }
}

