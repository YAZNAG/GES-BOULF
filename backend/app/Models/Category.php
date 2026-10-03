<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Category extends Model
{
    protected $table = 'categories';

    protected $fillable = [
        'nom',
        'name_ar',
        'name_fr',
        'description',
        'image',
        'famille_id',
    ];

    public function famille()
    {
        return $this->belongsTo(Famille::class);
    }

    public function sousCategories(): HasMany
    {
        return $this->hasMany(SousCategorie::class, 'categorie_id');
    }

    public function articles()
    {
        return $this->hasManyThrough(Article::class, SousCategorie::class, 'categorie_id', 'sous_categorie_id');
    }
}
