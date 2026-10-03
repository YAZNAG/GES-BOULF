<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Famille extends Model
{
    protected $fillable = ['nom_ar', 'nom_fr', 'image'];

    public function categories()
    {
        return $this->hasMany(Category::class);
    }

    public function sousCategories()
    {
        return $this->hasManyThrough(SousCategorie::class, Category::class, 'famille_id', 'categorie_id');
    }
}
