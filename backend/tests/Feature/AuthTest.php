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

    public function test_body_profile_can_be_updated_and_validated(): void
    {
        $token = $this->postJson('/api/auth/register', [
            'name' => 'Athlete',
            'email' => 'athlete@example.com',
            'password' => 'password123',
        ])->json('token');

        $this->withToken($token)->patchJson('/api/auth/me', [
            'sex' => 'female',
            'birth_date' => '2012-05-20',
            'height_cm' => 152,
            'weight_kg' => 41.5,
        ])->assertOk()
            ->assertJsonPath('user.sex', 'female')
            ->assertJsonPath('user.birth_date', '2012-05-20')
            ->assertJsonPath('user.height_cm', 152)
            ->assertJsonPath('user.weight_kg', 41.5);

        $this->withToken($token)->getJson('/api/auth/me')->assertJsonPath('user.height_cm', 152);

        $this->withToken($token)->patchJson('/api/auth/me', ['height_cm' => 400])->assertUnprocessable();
        $this->withToken($token)->patchJson('/api/auth/me', ['sex' => 'other'])->assertUnprocessable();
        $this->withToken($token)->patchJson('/api/auth/me', ['birth_date' => now()->addDay()->toDateString()])
            ->assertUnprocessable();
        // Email cannot be changed through this endpoint.
        $this->withToken($token)->patchJson('/api/auth/me', ['email' => 'x@example.com'])->assertOk();
        $this->assertDatabaseHas('users', ['email' => 'athlete@example.com']);
    }
}
