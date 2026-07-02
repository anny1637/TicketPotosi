<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Event extends Model
{
    protected $fillable = [
        'title',
        'description',
        'location',
        'event_date',
        'image',
        'video',
        'organizer',
        'organizer_logo',
        'banner_image',
        'category',
        'status',
        'capacity',
        'tickets_available',
    ];

    // Relación con ticket_types
    public function ticketTypes()
    {
        return $this->hasMany(TicketType::class);
    }

    // Relación con artistas
    public function artists()
    {
        return $this->belongsToMany(Artist::class, 'event_artists');
    }

    // Relación con preventa
    public function presale()
    {
        return $this->hasOne(Presale::class);
    }

    // Relación con promociones
    public function promotions()
    {
        return $this->hasMany(Promotion::class);
    }

    // Relación con tickets
    public function tickets()
    {
        return $this->hasMany(Ticket::class);
    }
}