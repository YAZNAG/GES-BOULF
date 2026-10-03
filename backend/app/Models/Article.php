<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Article extends Model
{
    protected $table = 'articles';

    protected $fillable =[
        'sous_categorie_id',
        'marque_id',
        'code_article',
        'nom',
        'name_ar',
        'name_fr',
        'description',
        'unite',
        'image',
        'actif',
    ];

    protected $casts = [
        'actif' => 'boolean',
    ];

    public function sousCategorie(): BelongsTo
    {
        return $this->belongsTo(SousCategorie::class, 'sous_categorie_id');
    }

    public function prix(): HasOne
    {
        return $this->hasOne(PrixArticle::class, 'article_id');
    }

    public function stock(): HasOne
    {
        return $this->hasOne(Stock::class, 'article_id');
    }

    public function mouvements(): HasMany
    {
        return $this->hasMany(MouvementStock::class, 'article_id');
    }

    public function sorties(): HasMany
    {
        return $this->hasMany(Sortie::class, 'article_id');
    }

    public function marque(): BelongsTo
    {
        return $this->belongsTo(Marque::class, 'marque_id');
    }
}

