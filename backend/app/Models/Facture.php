<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Facture extends Model
{
    protected $table = 'factures';

    protected $fillable = [
        'vente_id',
        'numero_facture',
        'date_facture',
        'montant_ttc',
        'statut',
        'pdf_path',
    ];

    protected $casts = [
        'date_facture' => 'datetime',
    ];

    public function vente(): BelongsTo
    {
        return $this->belongsTo(Vente::class);
    }
}
