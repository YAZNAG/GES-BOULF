<?php

namespace App\Http\Controllers\Api;

use App\Models\LigneCommandeVente;

class LigneCommandeVenteController extends CrudController
{
    protected string $modelClass = LigneCommandeVente::class;

    protected array $with = ['commande', 'article'];

    protected array $storeRules = [
        'commande_vente_id' => ['required', 'integer', 'exists:commandes_vente,id'],
        'article_id' => ['required', 'integer', 'exists:articles,id'],
        'quantite' => ['required', 'numeric', 'gt:0'],
        'prix_unitaire' => ['required', 'numeric', 'min:0'],
        'remise' => ['nullable', 'numeric', 'min:0', 'max:100'],
    ];

    protected array $updateRules = [
        'quantite' => ['sometimes', 'required', 'numeric', 'gt:0'],
        'prix_unitaire' => ['sometimes', 'required', 'numeric', 'min:0'],
        'remise' => ['nullable', 'numeric', 'min:0', 'max:100'],
    ];
}

