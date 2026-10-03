<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Règlement versé à un fournisseur (diminue son solde / crédit). */
class PaiementFournisseur extends Model
{
    protected $table = 'paiements_fournisseur';

    protected $fillable = ['fournisseur_id', 'reception_id', 'montant', 'mode', 'date_paiement', 'reference', 'note', 'utilisateur_id'];

    protected $casts = [
        'montant' => 'float',
        'date_paiement' => 'date:Y-m-d',
    ];

    public function fournisseur(): BelongsTo
    {
        return $this->belongsTo(Fournisseur::class, 'fournisseur_id');
    }

    public function reception(): BelongsTo
    {
        return $this->belongsTo(Reception::class, 'reception_id');
    }
}
