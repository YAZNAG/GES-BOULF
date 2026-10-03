<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class HistoriqueAction extends Model
{
    protected $table = 'historique_actions';

    protected $fillable = [
        'utilisateur_id',
        'action',
        'table_cible',
        'enregistrement_id',
        'details',
    ];

    protected $casts = [
        'details' => 'array',
    ];

    public function utilisateur(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class, 'utilisateur_id');
    }
}
