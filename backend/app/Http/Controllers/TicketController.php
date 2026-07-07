<?php

namespace App\Http\Controllers;

use App\Models\Ticket;
use App\Models\TicketType;
use App\Models\Attendance;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

use App\Models\Payment;

class TicketController extends Controller
{
    // COMPRAR TICKET
    public function purchase(Request $request)
    {
        self::releaseExpiredReservations();
        $request->validate([
            'ticket_type_id' => 'required|exists:ticket_types,id',
            'payment_method' => 'nullable|string|in:efectivo,qr,banco',
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
            $method = $request->payment_method ?? 'qr';
            $status = ($method === 'efectivo') ? 'pending' : 'paid';

            $ticket = Ticket::create([
                'user_id'        => $request->user()->id,
                'event_id'       => $ticketType->event_id,
                'ticket_type_id' => $ticketType->id,
                'status'         => $status,
            ]);

            // Registrar el pago
            Payment::create([
                'ticket_id'      => $ticket->id,
                'amount'         => $ticketType->price,
                'payment_method' => $method,
                'status'         => ($status === 'paid') ? 'completed' : 'pending',
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
        self::releaseExpiredReservations();
        $tickets = Ticket::with(['event', 'ticketType'])
                        ->where('user_id', $request->user()->id)
                        ->orderBy('created_at', 'desc')
                        ->get();

        return response()->json($tickets);
    }

    // VER TICKET CON QR
    public function show($id, Request $request)
    {
        self::releaseExpiredReservations();
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
        self::releaseExpiredReservations();
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
        self::releaseExpiredReservations();
        $tickets = Ticket::with(['event', 'ticketType', 'user'])
                        ->orderBy('created_at', 'desc')
                        ->get();

        return response()->json($tickets);
    }

    // EXPIRACIÓN AUTOMÁTICA DE RESERVAS (6 Horas)
    private static function releaseExpiredReservations()
    {
        // Auto-limpieza de tickets huérfanos cuyos eventos ya no existen
        $orphanTicketIds = Ticket::whereNotExists(function ($query) {
            $query->select(DB::raw(1))
                  ->from('events')
                  ->whereRaw('events.id = tickets.event_id');
        })->pluck('id');

        if ($orphanTicketIds->isNotEmpty()) {
            DB::transaction(function () use ($orphanTicketIds) {
                Payment::whereIn('ticket_id', $orphanTicketIds)->delete();
                Attendance::whereIn('ticket_id', $orphanTicketIds)->delete();
                Ticket::whereIn('id', $orphanTicketIds)->delete();
            });
        }

        $expiredTime = now()->subHours(6);

        $expiredTickets = Ticket::where('status', 'pending')
                                ->where('created_at', '<', $expiredTime)
                                ->get();

        if ($expiredTickets->isEmpty()) {
            return;
        }

        DB::transaction(function () use ($expiredTickets) {
            foreach ($expiredTickets as $ticket) {
                // Cambiar estado a expirado
                $ticket->update(['status' => 'expired']);

                // Cancelar pago pendiente
                Payment::where('ticket_id', $ticket->id)
                       ->where('status', 'pending')
                       ->update(['status' => 'failed']);

                // Devolver stock
                $ticketType = TicketType::with('event')->find($ticket->ticket_type_id);
                if ($ticketType) {
                    $ticketType->increment('stock');
                    if ($ticketType->event) {
                        $ticketType->event->increment('tickets_available');
                    }
                }
            }
        });
    }
}