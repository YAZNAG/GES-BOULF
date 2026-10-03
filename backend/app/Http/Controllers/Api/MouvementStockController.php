<?php

namespace App\Http\Controllers\Api;

use App\Models\MouvementStock;

class MouvementStockController extends CrudController
{
    protected string $modelClass = MouvementStock::class;

    protected array $with = ['article', 'utilisateur', 'fournisseur'];

    protected array $storeRules = [
        'article_id' => ['required', 'integer', 'exists:articles,id'],
        'fournisseur_id' => ['nullable', 'integer', 'exists:fournisseurs,id'],
        'type_mouvement' => ['required', 'in:entree,sortie'],
        'motif' => ['required', 'in:achat,vente,perte,don,retour,ajustement'],
        'quantite' => ['required', 'numeric', 'gt:0'],
        'reference_id' => ['nullable', 'integer'],
        'reference_type' => ['nullable', 'string', 'max:50'],
        'utilisateur_id' => ['nullable', 'integer', 'exists:utilisateurs,id'],
        'note' => ['nullable', 'string'],
    ];

    protected array $updateRules = [
        'note' => ['nullable', 'string'],
    ];
}

