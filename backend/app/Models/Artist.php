<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Artist extends Model
{
    protected $fillable = [
        'name',
        'photo',
        'description',
    ];

    public function events()
    {
        return $this->belongsToMany(Event::class, 'event_artists');
    }
}