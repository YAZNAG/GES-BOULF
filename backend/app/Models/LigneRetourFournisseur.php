<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LigneRetourFournisseur extends Model
{
    protected $table = 'lignes_retour_fournisseur';

    protected $fillable = ['retour_fournisseur_id', 'article_id', 'quantite', 'prix_achat'];

    protected $casts = ['quantite' => 'float', 'prix_achat' => 'float'];

    public function article(): BelongsTo
    {
        return $this->belongsTo(Article::class, 'article_id');
    }
}
