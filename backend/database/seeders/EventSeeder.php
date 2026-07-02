<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Event;
use App\Models\TicketType;
use App\Models\Presale;

class EventSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Evento de Conciertos
        $event1 = Event::create([
            'title'             => 'Gran Concierto de Gala Potosí',
            'description'       => 'Disfruta de una noche mágica de música clásica y folklore potosino con los mejores artistas de la región en el Teatro Municipal.',
            'location'          => 'Teatro Municipal de Potosí',
            'event_date'        => now()->addDays(10)->setTime(20, 0),
            'organizer'         => 'Gobernación de Potosí',
            'category'          => 'Conciertos',
            'capacity'          => 500,
            'tickets_available' => 500,
            'status'            => 'active',
        ]);

        // Tipos de entradas para evento 1
        $vip = TicketType::create([
            'event_id' => $event1->id,
            'name'     => 'VIP',
            'price'    => 150.00,
            'stock'    => 100,
        ]);

        $general = TicketType::create([
            'event_id' => $event1->id,
            'name'     => 'General',
            'price'    => 70.00,
            'stock'    => 400,
        ]);

        // Preventa para el VIP de concierto
        Presale::create([
            'event_id'       => $event1->id,
            'ticket_type_id' => $vip->id,
            'start_date'     => now()->subDays(1),
            'end_date'       => now()->addDays(5),
            'presale_price'  => 120.00,
            'is_active'      => true,
        ]);

        // 2. Evento de Deportes
        $event2 = Event::create([
            'title'             => 'Clásico de Fútbol Potosino',
            'description'       => 'El encuentro más esperado del año entre los gigantes de Potosí. ¡Ven a apoyar a tu equipo favorito!',
            'location'          => 'Estadio Víctor Agustín Ugarte',
            'event_date'        => now()->addDays(15)->setTime(15, 30),
            'organizer'         => 'Alcaldía de Potosí',
            'category'          => 'Deportes',
            'capacity'          => 2000,
            'tickets_available' => 2000,
            'status'            => 'active',
        ]);

        // Tipos de entradas para evento 2
        TicketType::create([
            'event_id' => $event2->id,
            'name'     => 'Preferencia',
            'price'    => 50.00,
            'stock'    => 500,
        ]);

        TicketType::create([
            'event_id' => $event2->id,
            'name'     => 'Curva',
            'price'    => 20.00,
            'stock'    => 1500,
        ]);
    }
}
