<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'max:72'],
        ]);

        $this->validatePasswordBytes($data['password']);

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => $data['password'],
        ]);

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'user' => $user,
            'token' => $token,
        ], 201);
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'string', 'email'],
            'password' => ['required', 'string', 'max:72'],
        ]);

        $this->validatePasswordBytes($data['password']);

        $user = User::where('email', $data['email'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Invalid credentials.'],
            ]);
        }

        $token = $user->createToken('mobile')->plainTextToken;

        return response()->json([
            'user' => $user,
            'token' => $token,
        ]);
    }

    private function validatePasswordBytes(string $password): void
    {
        if (strlen($password) > 72 || str_contains($password, "\0")) {
            throw ValidationException::withMessages([
                'password' => ['Password must not exceed 72 UTF-8 bytes or contain null characters.'],
            ]);
        }
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->json(['ok' => true]);
    }

    public function me(Request $request)
    {
        return response()->json(['user' => $request->user()]);
    }

    /** Update the body profile (sex, birth date, height, weight). */
    public function updateProfile(Request $request)
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'sex' => ['sometimes', 'nullable', 'in:male,female'],
            'birth_date' => ['sometimes', 'nullable', 'date_format:Y-m-d', 'before:today', 'after:1900-01-01'],
            'height_cm' => ['sometimes', 'nullable', 'integer', 'between:80,250'],
            'weight_kg' => ['sometimes', 'nullable', 'numeric', 'between:20,250'],
        ]);

        $user = $request->user();
        $user->fill($data)->save();

        return response()->json(['user' => $user->fresh()]);
    }
}
