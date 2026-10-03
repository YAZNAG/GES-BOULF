<?php

namespace App\Http\Controllers\Api;

use App\Models\Client;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

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

    /** Téléphone facultatif mais unique (espaces, points et tirets ignorés). */
    public function store(Request $request)
    {
        $this->normaliserTelephone($request);
        $this->storeRules['telephone'] = ['nullable', 'string', 'max:20', Rule::unique('clients', 'telephone')];

        return parent::store($request);
    }

    public function update(Request $request, string $id)
    {
        $this->normaliserTelephone($request, $id);
        $this->updateRules['telephone'] = ['nullable', 'string', 'max:20', Rule::unique('clients', 'telephone')->ignore($id)];

        return parent::update($request, $id);
    }

    private function normaliserTelephone(Request $request, ?string $id = null): void
    {
        if ($request->has('telephone')) {
            $tel = preg_replace('/[\s.\-]/', '', (string) $request->input('telephone'));
            $request->merge(['telephone' => $tel === '' ? null : $tel]);
            if ($tel !== '') {
                $autre = Client::query()->where('telephone', $tel)->when($id, fn ($q) => $q->whereKeyNot($id))->first();
                if ($autre) {
                    throw \Illuminate\Validation\ValidationException::withMessages([
                        'telephone' => "Ce numéro est déjà celui du client « {$autre->nom} ».",
                    ]);
                }
            }
        }
    }

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

