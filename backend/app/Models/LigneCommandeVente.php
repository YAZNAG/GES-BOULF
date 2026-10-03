<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LigneCommandeVente extends Model
{
    protected $table = 'lignes_commande_vente';

    protected $fillable = [
        'commande_vente_id',
        'article_id',
        'quantite',
        'prix_unitaire',
        'remise',
    ];

    public function commande(): BelongsTo
    {
        return $this->belongsTo(CommandeVente::class, 'commande_vente_id');
    }

    public function article(): BelongsTo
    {
        return $this->belongsTo(Article::class, 'article_id');
    }
}

