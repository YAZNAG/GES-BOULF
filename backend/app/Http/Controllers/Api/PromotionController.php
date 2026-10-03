<?php

namespace App\Http\Controllers\Api;

use App\Models\Promotion;

class PromotionController extends CrudController
{
    protected string $modelClass = Promotion::class;

    protected array $storeRules = [
        'name' => ['required', 'string', 'max:150'],
        'code_promo' => ['nullable', 'string', 'max:50'],
        'type' => ['required', 'in:pourcentage,montant_fixe'],
        'value' => ['required', 'numeric', 'min:0'],
        'panier_min' => ['nullable', 'numeric', 'min:0'],
        'start_date' => ['required', 'date'],
        'end_date' => ['required', 'date', 'after_or_equal:start_date'],
        'target_type' => ['required', 'in:article,category,client'],
        'target_id' => ['required', 'integer'],
        'is_active' => ['nullable', 'boolean'],
    ];

    protected array $updateRules = [
        'name' => ['sometimes', 'required', 'string', 'max:150'],
        'code_promo' => ['nullable', 'string', 'max:50'],
        'type' => ['sometimes', 'required', 'in:pourcentage,montant_fixe'],
        'value' => ['sometimes', 'required', 'numeric', 'min:0'],
        'panier_min' => ['nullable', 'numeric', 'min:0'],
        'start_date' => ['sometimes', 'required', 'date'],
        'end_date' => ['sometimes', 'required', 'date'],
        'target_type' => ['sometimes', 'required', 'in:article,category,client'],
        'target_id' => ['sometimes', 'required', 'integer'],
        'is_active' => ['nullable', 'boolean'],
    ];
}
