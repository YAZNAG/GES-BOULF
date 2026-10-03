<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CategorieCharge extends Model
{
    protected $table = 'categories_charges';

    protected $fillable = ['nom', 'icone', 'couleur', 'actif'];

    protected $casts = ['actif' => 'boolean'];

    public function charges(): HasMany
    {
        return $this->hasMany(Charge::class, 'categorie_charge_id');
    }
}
