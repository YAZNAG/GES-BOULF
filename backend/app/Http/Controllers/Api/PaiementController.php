<?php

namespace App\Http\Controllers\Api;

use App\Models\Paiement;
use App\Models\Client;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PaiementController extends CrudController
{
    protected string $modelClass = Paiement::class;

    protected array $with = ['client', 'vente', 'utilisateur'];

    protected array $storeRules = [
        'client_id' => ['required', 'integer', 'exists:clients,id'],
        'vente_id' => ['nullable', 'integer', 'exists:ventes,id'],
        'montant' => ['required', 'numeric', 'gt:0'],
        'mode' => ['required', 'string'],
        'note' => ['nullable', 'string'],
    ];

    public function store(Request $request)
    {
        $data = $request->validate($this->storeRules);

        $result = DB::transaction(function () use ($data) {
            $paiement = Paiement::create([
                'client_id' => $data['client_id'],
                'vente_id' => $data['vente_id'] ?? null,
                'montant' => $data['montant'],
                'mode' => $data['mode'],
                'note' => $data['note'] ?? null,
                'utilisateur_id' => auth()->id() ?? 1,
            ]);

            // Update client balance (decrement solde)
            $client = Client::find($data['client_id']);
            $client->decrement('solde', $data['montant']);

            $this->logAction('create', $paiement->getTable(), (int) $paiement->getKey(), $data);

            return $paiement->fresh($this->with);
        });

        return response()->json($result, 201);
    }
}
