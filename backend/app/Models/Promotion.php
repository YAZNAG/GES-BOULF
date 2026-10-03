<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\MorphTo;

class Promotion extends Model
{
    protected $table = 'promotions';

    protected $fillable = [
        'name',
        'code_promo',
        'type',
        'value',
        'panier_min',
        'start_date',
        'end_date',
        'target_type',
        'target_id',
        'is_active',
    ];

    protected $casts = [
        'start_date' => 'date',
        'end_date' => 'date',
        'is_active' => 'boolean',
    ];

    public function target(): MorphTo
    {
        return $this->morphTo(null, 'target_type', 'target_id');
    }
}
