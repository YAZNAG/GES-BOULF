<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** Session d'inventaire (comptage physique). Statuts : en_cours, valide, annule. */
class Inventaire extends Model
{
    protected $fillable = ['numero', 'libelle', 'statut', 'famille_id', 'categorie_id', 'valide_le', 'note', 'utilisateur_id', 'valide_par'];

    protected $casts = ['valide_le' => 'datetime'];

    public function lignes(): HasMany
    {
        return $this->hasMany(LigneInventaire::class, 'inventaire_id');
    }

    public function famille(): BelongsTo
    {
        return $this->belongsTo(Famille::class, 'famille_id');
    }

    public function categorie(): BelongsTo
    {
        return $this->belongsTo(Category::class, 'categorie_id');
    }

    public function utilisateur(): BelongsTo
    {
        return $this->belongsTo(Utilisateur::class, 'utilisateur_id');
    }
}
