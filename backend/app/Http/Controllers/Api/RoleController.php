<?php

namespace App\Http\Controllers\Api;

use App\Models\Role;

class RoleController extends CrudController
{
    protected string $modelClass = Role::class;

    protected array $storeRules = [
        'nom' => ['required', 'string', 'max:50', 'unique:roles,nom'],
        'description' => ['nullable', 'string'],
        'permissions' => ['nullable', 'array'],
        'permissions.*' => ['string'],
    ];

    protected array $updateRules = [
        'nom' => ['sometimes', 'required', 'string', 'max:50'],
        'description' => ['nullable', 'string'],
        'permissions' => ['nullable', 'array'],
        'permissions.*' => ['string'],
    ];
}
