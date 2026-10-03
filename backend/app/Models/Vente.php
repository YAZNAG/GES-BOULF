<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Vente extends Model
{
    protected $table = 'ventes';

    protected $fillable = [
        'commande_vente_id',
        'client_id',
        'montant_total',
        'montant_remise',
        'montant_paye',
        'mode_paiement',
        'date_vente',
        'utilisateur_id',
    ];

    protected $casts = [
        'date_vente' => 'datetime',
    ];

    public function items()
    {
        return $this->hasMany(LigneCommandeVente::class, 'commande_vente_id', 'commande_vente_id');
    }

    public function commande(): BelongsTo
    {
        return $this->belongsTo(CommandeVente::class, 'commande_vente_id');
    }

    public function client(): BelongsTo
    {
        return $this->belongsTo(Client::class, 'client_id');
    }

    public function utilisateur(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class, 'utilisateur_id');
    }

    public function facture(): HasOne
    {
        return $this->hasOne(Facture::class, 'vente_id');
    }
}
