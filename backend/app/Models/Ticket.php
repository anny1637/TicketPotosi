<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class Ticket extends Model
{
    protected $fillable = [
        'user_id',
        'event_id',
        'ticket_type_id',
        'ticket_code',
        'qr_token',
        'status',
        'purchase_date',
    ];

    // Genera código y QR automáticamente
    protected static function boot()
    {
        parent::boot();

        static::creating(function ($ticket) {
            $ticket->ticket_code  = 'TKT-' . strtoupper(Str::random(8));
            $ticket->qr_token     = Str::uuid();
            $ticket->purchase_date = now();
        });
    }

    // Relaciones
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function event()
    {
        return $this->belongsTo(Event::class);
    }

    public function ticketType()
    {
        return $this->belongsTo(TicketType::class);
    }

    public function attendance()
    {
        return $this->hasOne(Attendance::class);
    }
}