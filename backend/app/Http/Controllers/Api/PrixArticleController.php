<?php

namespace App\Http\Controllers\Api;

use App\Models\PrixArticle;

class PrixArticleController extends CrudController
{
    protected string $modelClass = PrixArticle::class;

    protected array $with = ['article'];

    protected array $storeRules = [
        'article_id' => ['required', 'integer', 'exists:articles,id', 'unique:prix_articles,article_id'],
        'prix_achat' => ['required', 'numeric', 'min:0'],
        'prix_vente' => ['required', 'numeric', 'min:0'],
        'prix_gros' => ['nullable', 'numeric', 'min:0'],
        'prix_promo' => ['nullable', 'numeric', 'min:0'],
    ];

    protected array $updateRules = [
        'prix_achat' => ['sometimes', 'required', 'numeric', 'min:0'],
        'prix_vente' => ['sometimes', 'required', 'numeric', 'min:0'],
        'prix_gros' => ['nullable', 'numeric', 'min:0'],
        'prix_promo' => ['nullable', 'numeric', 'min:0'],
    ];
}

