<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\Storage;

class Marque extends Model
{
    use HasFactory;

    protected $fillable = [
        'nom',
        'image',
        'description',
    ];

    protected $appends = ['image_url'];

    public function getImageUrlAttribute(): ?string
    {
        if (!$this->image) return null;
        if (str_starts_with($this->image, 'http')) return $this->image;
        return asset(Storage::url($this->image));
    }

    public function articles(): HasMany
    {
        return $this->hasMany(Article::class);
    }
}
