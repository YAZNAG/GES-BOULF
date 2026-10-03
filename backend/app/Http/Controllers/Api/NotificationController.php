<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\HistoriqueAction;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request)
    {
        $limit = (int) $request->query('limit', 12);
        $limit = max(1, min(50, $limit));

        $items = HistoriqueAction::query()
            ->with('utilisateur')
            ->orderByDesc('id')
            ->limit($limit)
            ->get();

        return response()->json([
            'data' => $items,
        ]);
    }
}

