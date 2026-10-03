<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LigneCommandeAchat extends Model
{
    protected $table = 'lignes_commande_achat';

    protected $fillable = ['commande_achat_id', 'article_id', 'quantite', 'quantite_recue', 'prix_unitaire'];

    protected $casts = [
        'quantite' => 'float',
        'quantite_recue' => 'float',
        'prix_unitaire' => 'float',
    ];

    public function commande(): BelongsTo
    {
        return $this->belongsTo(CommandeAchat::class, 'commande_achat_id');
    }

    public function article(): BelongsTo
    {
        return $this->belongsTo(Article::class, 'article_id');
    }
}
