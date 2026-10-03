<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Fournisseur extends Model
{
    protected $table = 'fournisseurs';

    protected $fillable = [
        'nom',
        'telephone',
        'email',
        'adresse',
        'actif',
    ];

    protected $casts = [
        'actif' => 'boolean',
    ];
}

