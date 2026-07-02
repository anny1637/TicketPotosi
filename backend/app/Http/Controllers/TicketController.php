<?php

namespace App\Http\Controllers;

use App\Models\Ticket;
use App\Models\TicketType;
use App\Models\Attendance;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class TicketController extends Controller
{
    // COMPRAR TICKET
    public function purchase(Request $request)
{
    $request->validate([
        'ticket_type_id' => 'required|exists:ticket_types,id',
    ]);

    $ticketType = TicketType::with('event')->find($request->ticket_type_id);

    // Verificar stock
    if ($ticketType->stock <= 0) {
        return response()->json([
            'message' => 'No hay tickets disponibles'
        ], 400);
    }

    // Verificar que el evento esté activo
    if ($ticketType->event->status !== 'active') {
        return response()->json([
            'message' => 'El evento no está disponible'
        ], 400);
    }

    // Crear ticket y reducir stock
    $ticket = null;

    DB::transaction(function () use ($request, $ticketType, &$ticket) {
        $ticket = Ticket::create([
            'user_id'        => $request->user()->id,
            'event_id'       => $ticketType->event_id,
            'ticket_type_id' => $ticketType->id,
            'status'         => 'paid',
        ]);

        $ticketType->decrement('stock');
        $ticketType->event->decrement('tickets_available');
    });

    return response()->json([
        'message' => 'Ticket comprado correctamente',
        'ticket'  => $ticket ? $ticket->load(['event', 'ticketType']) : null,
    ], 201);
}

    // MIS TICKETS
    public function myTickets(Request $request)
    {
        $tickets = Ticket::with(['event', 'ticketType'])
                        ->where('user_id', $request->user()->id)
                        ->orderBy('created_at', 'desc')
                        ->get();

        return response()->json($tickets);
    }

    // VER TICKET CON QR
    public function show($id, Request $request)
    {
        $ticket = Ticket::with(['event', 'ticketType'])
                        ->where('id', $id)
                        ->where('user_id', $request->user()->id)
                        ->first();

        if (!$ticket) {
            return response()->json(['message' => 'Ticket no encontrado'], 404);
        }

        return response()->json($ticket);
    }

    // VALIDAR QR (Scanner)
    public function validateQR(Request $request)
    {
        $request->validate([
            'qr_token' => 'required|string',
        ]);

        $ticket = Ticket::with(['event', 'ticketType', 'user'])
                        ->where('qr_token', $request->qr_token)
                        ->first();

        if (!$ticket) {
            return response()->json([
                'message' => 'QR inválido',
                'valid'   => false,
            ], 404);
        }

        if ($ticket->status === 'used') {
            return response()->json([
                'message' => 'Ticket ya fue usado',
                'valid'   => false,
                'ticket'  => $ticket,
            ], 400);
        }

        if ($ticket->status !== 'paid') {
            return response()->json([
                'message' => 'Ticket no válido',
                'valid'   => false,
                'ticket'  => $ticket,
            ], 400);
        }

        // Marcar como usado
        DB::transaction(function () use ($ticket, $request) {
            $ticket->update(['status' => 'used']);

            Attendance::create([
                'ticket_id'    => $ticket->id,
                'checkin_time' => now(),
                'validated_by' => $request->user()->id,
            ]);
        });

        return response()->json([
            'message' => 'Ticket válido ✅',
            'valid'   => true,
            'ticket'  => $ticket,
        ]);
    }

    // VER TODOS LOS TICKETS (Admin)
    public function allTickets()
    {
        $tickets = Ticket::with(['event', 'ticketType', 'user'])
                        ->orderBy('created_at', 'desc')
                        ->get();

        return response()->json($tickets);
    }
}