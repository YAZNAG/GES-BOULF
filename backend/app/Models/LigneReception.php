<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LigneReception extends Model
{
    protected $table = 'lignes_reception';

    protected $fillable = ['reception_id', 'article_id', 'ligne_commande_achat_id', 'quantite', 'prix_achat', 'prix_vente'];

    protected $casts = [
        'quantite' => 'float',
        'prix_achat' => 'float',
        'prix_vente' => 'float',
    ];

    public function reception(): BelongsTo
    {
        return $this->belongsTo(Reception::class, 'reception_id');
    }

    public function article(): BelongsTo
    {
        return $this->belongsTo(Article::class, 'article_id');
    }
}
