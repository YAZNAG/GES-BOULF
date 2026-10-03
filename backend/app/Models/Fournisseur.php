<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Fournisseur extends Model
{
    protected $table = 'fournisseurs';

    protected $fillable = [
        'code', 'nom', 'contact', 'telephone', 'email', 'adresse', 'ville', 'ice', 'rc',
        'solde', 'plafond_credit', 'delai_paiement', 'note', 'actif',
    ];

    protected $casts = [
        'actif' => 'boolean',
        'solde' => 'float',
        'plafond_credit' => 'float',
        'delai_paiement' => 'integer',
    ];

    public function commandes(): HasMany
    {
        return $this->hasMany(CommandeAchat::class, 'fournisseur_id');
    }

    public function receptions(): HasMany
    {
        return $this->hasMany(Reception::class, 'fournisseur_id');
    }

    public function paiements(): HasMany
    {
        return $this->hasMany(PaiementFournisseur::class, 'fournisseur_id');
    }
}
