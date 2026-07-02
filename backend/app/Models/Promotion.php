<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Promotion extends Model
{
    protected $fillable = [
        'event_id',
        'title',
        'description',
        'code',
        'discount_percentage',
        'image',
        'start_date',
        'end_date',
        'is_active',
    ];

    protected $casts = [
        'is_active'  => 'boolean',
        'start_date' => 'datetime',
        'end_date'   => 'datetime',
    ];

    public function event()
    {
        return $this->belongsTo(Event::class);
    }

    // Verificar si la promoción está vigente
    public function isCurrentlyActive(): bool
    {
        $now = now();
        return $this->is_active
            && $this->start_date <= $now
            && $this->end_date >= $now;
    }
}
