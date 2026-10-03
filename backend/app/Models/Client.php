<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Client extends Model
{
    protected $table = 'clients';

    protected $fillable = [
        'nom',
        'telephone',
        'email',
        'adresse',
        'type_client',
        'solde',
        'actif',
    ];

    protected $casts = [
        'actif' => 'boolean',
        'solde' => 'decimal:2',
    ];

    public function commandesVente(): HasMany
    {
        return $this->hasMany(CommandeVente::class, 'client_id');
    }

    public function paiements(): HasMany
    {
        return $this->hasMany(Paiement::class, 'client_id');
    }
}

