<?php

namespace App\Http\Controllers\Api;

use App\Models\Client;

class ClientController extends CrudController
{
    protected string $modelClass = Client::class;

    protected array $storeRules = [
        'nom' => ['required', 'string', 'max:150'],
        'telephone' => ['nullable', 'string', 'max:20'],
        'email' => ['nullable', 'email', 'max:100'],
        'adresse' => ['nullable', 'string'],
        'type_client' => ['nullable', 'in:detail,gros'],
        'actif' => ['nullable', 'boolean'],
    ];

    protected array $updateRules = [
        'nom' => ['sometimes', 'required', 'string', 'max:150'],
        'telephone' => ['nullable', 'string', 'max:20'],
        'email' => ['nullable', 'email', 'max:100'],
        'adresse' => ['nullable', 'string'],
        'type_client' => ['nullable', 'in:detail,gros'],
        'actif' => ['nullable', 'boolean'],
    ];

    public function history($id)
    {
        $client = Client::findOrFail($id);
        
        $ventes = \App\Models\Vente::with(['facture', 'items.article'])
            ->where('client_id', $id)
            ->orderBy('created_at', 'desc')
            ->get();
            
        $paiements = \App\Models\Paiement::where('client_id', $id)
            ->orderBy('created_at', 'desc')
            ->get();
            
        $total_spent = $ventes->sum('montant_total');
            
        return response()->json([
            'client' => $client,
            'ventes' => $ventes,
            'paiements' => $paiements,
            'total_spent' => $total_spent
        ]);
    }
}

