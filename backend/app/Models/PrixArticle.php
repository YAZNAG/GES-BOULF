<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PrixArticle extends Model
{
    protected $table = 'prix_articles';

    protected $fillable = [
        'article_id',
        'prix_achat',
        'prix_vente',
        'prix_gros',
        'prix_promo',
    ];

    public function article(): BelongsTo
    {
        return $this->belongsTo(Article::class, 'article_id');
    }
}

