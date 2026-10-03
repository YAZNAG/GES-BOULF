<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SubCategory extends Model
{
    protected $table = 'sub_categories';

    protected $fillable = [
        'sous_categorie_id',
        'nom',
        'name_ar',
        'name_fr',
        'description',
        'image',
    ];

    public function sousCategorie(): BelongsTo
    {
        return $this->belongsTo(SousCategorie::class, 'sous_categorie_id');
    }

    public function articles(): HasMany
    {
        return $this->hasMany(Article::class, 'sub_categorie_id');
    }
}
