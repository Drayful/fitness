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

        $token = $res->json('token');
        $this->assertNotEmpty($token);
        $this->assertDatabaseHas('users', ['email' => 'test@example.com']);

        $this->withToken($token)->getJson('/api/auth/me')
            ->assertOk()
            ->assertJsonPath('user.email', 'test@example.com');

        $this->postJson('/api/auth/register', [
            'name' => 'Duplicate',
            'email' => 'test@example.com',
            'password' => 'password123',
        ])->assertUnprocessable()->assertJsonValidationErrors('email');

        $login = $this->postJson('/api/auth/login', [
            'email' => 'test@example.com',
            'password' => 'password123',
        ])->assertOk();
        $this->assertNotEmpty($login->json('token'));
    }
}
