<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Utilisateur extends Model
{
    protected $table = 'utilisateurs';

    protected $fillable = [
        'role_id',
        'nom',
        'prenom',
        'email',
        'mot_de_passe',
        'actif',
    ];

    protected $hidden = [
        'mot_de_passe',
    ];

    protected $casts = [
        'actif' => 'boolean',
        'mot_de_passe' => 'hashed',
    ];

    public function role(): BelongsTo
    {
        return $this->belongsTo(Role::class, 'role_id');
    }

    public function historiqueActions(): HasMany
    {
        return $this->hasMany(HistoriqueAction::class, 'utilisateur_id');
    }
}

