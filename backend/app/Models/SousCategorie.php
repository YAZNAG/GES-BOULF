<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SousCategorie extends Model
{
    protected $table = 'sous_categories';

    protected $fillable = [
        'categorie_id',
        'nom',
        'name_ar',
        'name_fr',
        'description',
        'image',
    ];

    public function categorie(): BelongsTo
    {
        return $this->belongsTo(Category::class, 'categorie_id');
    }

    public function articles(): HasMany
    {
        return $this->hasMany(Article::class, 'sous_categorie_id');
    }

    public function subCategories(): HasMany
    {
        return $this->hasMany(SubCategory::class, 'sous_categorie_id');
    }
}
