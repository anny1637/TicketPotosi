<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Attendance extends Model
{
    protected $table = 'attendance'; // ← indica el nombre exacto

    protected $fillable = [
        'ticket_id',
        'checkin_time',
        'validated_by',
    ];

    public function ticket()
    {
        return $this->belongsTo(Ticket::class);
    }

    public function validator()
    {
        return $this->belongsTo(User::class, 'validated_by');
    }
}