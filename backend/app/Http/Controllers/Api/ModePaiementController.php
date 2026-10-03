<?php

namespace App\Http\Controllers\Api;

use App\Models\ModePaiement;

class ModePaiementController extends CrudController
{
    protected string $modelClass = ModePaiement::class;

    protected array $storeRules = [
        'nom' => ['required', 'string', 'max:100'],
        'actif' => ['sometimes', 'boolean'],
    ];

    protected array $updateRules = [
        'nom' => ['sometimes', 'required', 'string', 'max:100'],
        'actif' => ['sometimes', 'boolean'],
    ];
}
