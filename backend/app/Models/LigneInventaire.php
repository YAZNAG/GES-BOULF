<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LigneInventaire extends Model
{
    protected $table = 'lignes_inventaire';

    protected $fillable = ['inventaire_id', 'article_id', 'quantite_theorique', 'quantite_comptee', 'prix_achat', 'utilisateur_id'];

    protected $casts = ['quantite_theorique' => 'float', 'quantite_comptee' => 'float', 'prix_achat' => 'float'];

    protected $appends = ['ecart', 'ecart_valeur'];

    public function getEcartAttribute(): float
    {
        return round($this->quantite_comptee - $this->quantite_theorique, 3);
    }

    public function getEcartValeurAttribute(): float
    {
        return round($this->ecart * $this->prix_achat, 2);
    }

    public function article(): BelongsTo
    {
        return $this->belongsTo(Article::class, 'article_id');
    }
}
