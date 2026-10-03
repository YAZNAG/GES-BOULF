<?php

namespace App\Http\Controllers\Api;

use App\Models\Utilisateur;

class UtilisateurController extends CrudController
{
    protected string $modelClass = Utilisateur::class;

    protected array $with = ['role'];

    protected array $storeRules = [
        'role_id' => ['required', 'integer', 'exists:roles,id'],
        'nom' => ['required', 'string', 'max:100'],
        'prenom' => ['nullable', 'string', 'max:100'],
        'email' => ['required', 'email', 'max:100', 'unique:utilisateurs,email'],
        'mot_de_passe' => ['required', 'string', 'min:6'],
        'actif' => ['nullable', 'boolean'],
    ];

    protected array $updateRules = [
        'role_id' => ['sometimes', 'required', 'integer', 'exists:roles,id'],
        'nom' => ['sometimes', 'required', 'string', 'max:100'],
        'prenom' => ['nullable', 'string', 'max:100'],
        'email' => ['sometimes', 'required', 'email', 'max:100'],
        'mot_de_passe' => ['nullable', 'string', 'min:6'],
        'actif' => ['nullable', 'boolean'],
    ];
}

