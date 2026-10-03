<?php

namespace App\Http\Controllers\Api;

use App\Models\Vente;

class VenteController extends CrudController
{
    protected string $modelClass = Vente::class;

    protected array $with = ['commande', 'client', 'utilisateur', 'items.article'];

    protected array $storeRules = [
        'commande_vente_id' => ['required', 'integer', 'exists:commandes_vente,id', 'unique:ventes,commande_vente_id'],
        'client_id' => ['nullable', 'integer', 'exists:clients,id'],
        'montant_total' => ['required', 'numeric', 'min:0'],
        'montant_remise' => ['nullable', 'numeric', 'min:0'],
        'montant_paye' => ['required', 'numeric', 'min:0'],
        'mode_paiement' => ['nullable', 'string'],
        'date_vente' => ['nullable', 'date'],
        'utilisateur_id' => ['nullable', 'integer', 'exists:utilisateurs,id'],
    ];

    protected array $updateRules = [
        'montant_total' => ['sometimes', 'required', 'numeric', 'min:0'],
        'montant_remise' => ['nullable', 'numeric', 'min:0'],
        'montant_paye' => ['sometimes', 'required', 'numeric', 'min:0'],
        'mode_paiement' => ['nullable', 'string'],
        'date_vente' => ['nullable', 'date'],
    ];
}
