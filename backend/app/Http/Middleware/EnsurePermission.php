<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsurePermission
{
    public function handle(Request $request, Closure $next, string $permission): Response
    {
        $user = $request->user();

        if (!$user) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }

        $user->loadMissing('role');

        $roleName = (string) ($user->role?->nom ?? '');
        if (strtolower($roleName) === 'admin') {
            return $next($request);
        }

        $permissions = $user->role?->permissions;
        $list = is_array($permissions) ? array_map('strval', $permissions) : [];

        $required = array_filter(array_map('trim', preg_split('/[|,]/', $permission) ?: []));
        foreach ($required as $p) {
            if (in_array($p, $list, true)) {
                return $next($request);
            }
        }

        return response()->json(['message' => 'Forbidden'], 403);
    }
}

