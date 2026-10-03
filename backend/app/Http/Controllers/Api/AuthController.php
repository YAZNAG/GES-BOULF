<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = User::query()->where('email', $data['email'])->first();

        if (!$user || !Hash::check($data['password'], $user->getAuthPassword())) {
            return response()->json(['message' => 'Identifiants invalides'], 422);
        }

        if (!$user->actif) {
            return response()->json(['message' => 'Compte désactivé'], 403);
        }

        $token = $user->createToken('frontend')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => $user->load('role'),
        ]);
    }

    public function me(Request $request)
    {
        return response()->json([
            'user' => $request->user()->load('role'),
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->json(['logged_out' => true]);
    }
}

