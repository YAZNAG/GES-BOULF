<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class CommandeVente extends Model
{
    protected $table = 'commandes_vente';

    protected $fillable = [
        'numero',
        'type_commande',
        'client_id',
        'statut',
        'total',
        'date_commande',
        'note',
        'utilisateur_id',
    ];

    protected $casts = [
        'date_commande' => 'datetime',
    ];

    protected static function boot()
    {
        parent::boot();

        static::creating(function ($model) {
            if (empty($model->numero)) {
                // Find the latest order to generate the next number
                $latest = self::orderBy('id', 'desc')->first();
                $nextId = $latest ? $latest->id + 1 : 1;
                $model->numero = '#ORD-' . str_pad($nextId, 4, '0', STR_PAD_LEFT);
            }
        });
    }

    public function client(): BelongsTo
    {
        return $this->belongsTo(Client::class, 'client_id');
    }

    public function utilisateur(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class, 'utilisateur_id');
    }

    public function lignes(): HasMany
    {
        return $this->hasMany(LigneCommandeVente::class, 'commande_vente_id');
    }

    public function vente(): HasOne
    {
        return $this->hasOne(Vente::class, 'commande_vente_id');
    }
}
