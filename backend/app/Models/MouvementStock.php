<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MouvementStock extends Model
{
    protected $table = 'mouvements_stock';

    protected $fillable = [
        'article_id',
        'fournisseur_id',
        'type_mouvement',
        'motif',
        'quantite',
        'reference_id',
        'reference_type',
        'utilisateur_id',
        'note',
    ];

    public function article(): BelongsTo
    {
        return $this->belongsTo(Article::class, 'article_id');
    }

    public function fournisseur(): BelongsTo
    {
        return $this->belongsTo(Fournisseur::class, 'fournisseur_id');
    }

    public function utilisateur(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class, 'utilisateur_id');
    }
}

