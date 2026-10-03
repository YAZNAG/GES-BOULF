<?php

namespace App\Http\Controllers\Api;

use App\Models\Facture;

class FactureController extends CrudController
{
    protected string $modelClass = Facture::class;

    protected array $with = ['vente', 'vente.client', 'vente.commande', 'vente.items', 'vente.items.article'];

    protected array $storeRules = [
        'vente_id' => ['required', 'integer', 'exists:ventes,id'],
        'numero_facture' => ['required', 'string', 'unique:factures,numero_facture'],
        'date_facture' => ['required', 'date'],
        'montant_ttc' => ['required', 'numeric', 'min:0'],
        'statut' => ['required', 'in:payée,en_attente,annulée'],
    ];

    protected array $updateRules = [
        'statut' => ['sometimes', 'required', 'in:payée,en_attente,annulée'],
    ];
}
