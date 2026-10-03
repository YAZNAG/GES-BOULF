<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Pack extends Model
{
    protected $table = 'packs';

    protected $fillable = [
        'nom',
        'description',
        'prix_vente',
        'image',
        'actif',
    ];

    protected $casts = [
        'prix_vente' => 'decimal:2',
        'actif' => 'boolean',
    ];

    public function items(): HasMany
    {
        return $this->hasMany(PackItem::class, 'pack_id');
    }
}

