<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PackItem extends Model
{
    protected $table = 'pack_items';

    protected $fillable = [
        'pack_id',
        'article_id',
        'quantite',
    ];

    protected $casts = [
        'quantite' => 'decimal:2',
    ];

    public function pack(): BelongsTo
    {
        return $this->belongsTo(Pack::class, 'pack_id');
    }

    public function article(): BelongsTo
    {
        return $this->belongsTo(Article::class, 'article_id');
    }
}

