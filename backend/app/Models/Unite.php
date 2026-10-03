<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Unite extends Model
{
    protected $table = 'unites';

    protected $fillable = [
        'nom',
        'description',
        'actif',
    ];
}
