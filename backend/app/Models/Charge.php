<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Dépense du magasin (loyer, électricité, salaires…). */
class Charge extends Model
{
    protected $fillable = ['categorie_charge_id', 'libelle', 'montant', 'date_charge', 'mode_paiement', 'reference', 'beneficiaire', 'piece', 'note', 'utilisateur_id'];

    protected $casts = ['montant' => 'float', 'date_charge' => 'date:Y-m-d'];

    public function categorie(): BelongsTo
    {
        return $this->belongsTo(CategorieCharge::class, 'categorie_charge_id');
    }

    public function utilisateur(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class, 'utilisateur_id');
    }
}
