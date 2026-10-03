<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** Bon de réception : entrée en stock des articles livrés par un fournisseur. */
class Reception extends Model
{
    protected $fillable = [
        'numero', 'fournisseur_id', 'commande_achat_id', 'date_reception', 'reference_fournisseur',
        'total', 'montant_paye', 'mode_paiement', 'note', 'utilisateur_id',
    ];

    protected $casts = [
        'date_reception' => 'date:Y-m-d',
        'total' => 'float',
        'montant_paye' => 'float',
    ];

    protected $appends = ['reste'];

    public function getResteAttribute(): float
    {
        return round((float) $this->total - (float) $this->montant_paye, 2);
    }

    public function fournisseur(): BelongsTo
    {
        return $this->belongsTo(Fournisseur::class, 'fournisseur_id');
    }

    public function commande(): BelongsTo
    {
        return $this->belongsTo(CommandeAchat::class, 'commande_achat_id');
    }

    public function lignes(): HasMany
    {
        return $this->hasMany(LigneReception::class, 'reception_id');
    }

    public function utilisateur(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class, 'utilisateur_id');
    }
}
