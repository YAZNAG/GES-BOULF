<?php

namespace App\Http\Controllers\Api;

use App\Models\Fournisseur;

class FournisseurController extends CrudController
{
    protected string $modelClass = Fournisseur::class;

    protected array $storeRules = [
        'nom' => ['required', 'string', 'max:150'],
        'telephone' => ['nullable', 'string', 'max:20'],
        'email' => ['nullable', 'email', 'max:100'],
        'adresse' => ['nullable', 'string'],
        'actif' => ['nullable', 'boolean'],
    ];

    protected array $updateRules = [
        'nom' => ['sometimes', 'required', 'string', 'max:150'],
        'telephone' => ['nullable', 'string', 'max:20'],
        'email' => ['nullable', 'email', 'max:100'],
        'adresse' => ['nullable', 'string'],
        'actif' => ['nullable', 'boolean'],
    ];
}

