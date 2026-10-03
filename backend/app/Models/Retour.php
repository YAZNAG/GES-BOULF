<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Retour extends Model
{
    protected $table = 'retours';

    protected $fillable = [
        'numero',
        'en_stock',
        'remboursement',
        'vente_id',
        'article_id',
        'quantite',
        'motif',
        'montant',
        'utilisateur_id',
    ];

    public function vente(): BelongsTo
    {
        return $this->belongsTo(Vente::class, 'vente_id');
    }

    public function article(): BelongsTo
    {
        return $this->belongsTo(Article::class, 'article_id');
    }

    public function utilisateur(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class, 'utilisateur_id');
    }
}
