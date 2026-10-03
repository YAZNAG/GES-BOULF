<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** Retour de marchandise à un fournisseur (bon RF-…). Règlement : avoir (déduit du crédit) ou remboursement. */
class RetourFournisseur extends Model
{
    protected $table = 'retours_fournisseur';

    protected $fillable = ['numero', 'fournisseur_id', 'reception_id', 'date_retour', 'motif', 'total', 'reglement', 'note', 'utilisateur_id'];

    protected $casts = ['date_retour' => 'date:Y-m-d', 'total' => 'float'];

    public function fournisseur(): BelongsTo
    {
        return $this->belongsTo(Fournisseur::class, 'fournisseur_id');
    }

    public function reception(): BelongsTo
    {
        return $this->belongsTo(Reception::class, 'reception_id');
    }

    public function lignes(): HasMany
    {
        return $this->hasMany(LigneRetourFournisseur::class, 'retour_fournisseur_id');
    }

    public function utilisateur(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class, 'utilisateur_id');
    }
}
