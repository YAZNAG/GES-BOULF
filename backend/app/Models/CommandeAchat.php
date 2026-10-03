<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** Bon de commande fournisseur. Statuts : brouillon, confirmee, partielle, recue, annulee. */
class CommandeAchat extends Model
{
    protected $table = 'commandes_achat';

    protected $fillable = [
        'numero', 'fournisseur_id', 'statut', 'date_commande', 'date_prevue', 'date_reception',
        'total', 'note', 'utilisateur_id',
    ];

    protected $casts = [
        'date_commande' => 'date:Y-m-d',
        'date_prevue' => 'date:Y-m-d',
        'date_reception' => 'date:Y-m-d',
        'total' => 'decimal:2',
    ];

    public function fournisseur(): BelongsTo
    {
        return $this->belongsTo(Fournisseur::class, 'fournisseur_id');
    }

    public function lignes(): HasMany
    {
        return $this->hasMany(LigneCommandeAchat::class, 'commande_achat_id');
    }

    public function receptions(): HasMany
    {
        return $this->hasMany(Reception::class, 'commande_achat_id');
    }

    public function utilisateur(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class, 'utilisateur_id');
    }
}
