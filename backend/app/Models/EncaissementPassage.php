<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Encaissement ultérieur du reste dû par un client de passage. */
class EncaissementPassage extends Model
{
    protected $table = 'encaissements_passage';

    protected $fillable = ['vente_id', 'montant', 'mode', 'note', 'utilisateur_id'];

    protected $casts = ['montant' => 'float'];

    public function vente(): BelongsTo
    {
        return $this->belongsTo(Vente::class, 'vente_id');
    }

    public function utilisateur(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class, 'utilisateur_id');
    }
}
