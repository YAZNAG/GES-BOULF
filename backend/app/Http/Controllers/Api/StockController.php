<?php

namespace App\Http\Controllers\Api;

use App\Models\Stock;

class StockController extends CrudController
{
    protected string $modelClass = Stock::class;

    protected array $with = ['article'];

    protected array $storeRules = [
        'article_id' => ['required', 'integer', 'exists:articles,id', 'unique:stock,article_id'],
        'quantite' => ['nullable', 'numeric'],
        'seuil_min' => ['nullable', 'numeric', 'min:0'],
    ];

    protected array $updateRules = [
        'quantite' => ['sometimes', 'required', 'numeric'],
        'seuil_min' => ['nullable', 'numeric', 'min:0'],
    ];
}

