<?php

namespace App\Http\Controllers;

use App\Models\Event;
use App\Models\Ticket;
use App\Models\User;
use App\Models\Promotion;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AdminController extends Controller
{
    public function __construct()
    {
        // Middleware para verificar admin
    }

    private function authorizeAdmin(Request $request)
    {
        if (!$request->user() || $request->user()->role_id !== 1) {
            abort(403, 'Acceso denegado. Solo administradores.');
        }
    }

    // ─── DASHBOARD ESTADÍSTICAS ───────────────────────────────────────────────
    public function dashboard(Request $request)
    {
        $this->authorizeAdmin($request);

        $totalTickets   = Ticket::where('status', 'paid')->count();
        $usedTickets    = Ticket::where('status', 'used')->count();
        $totalEvents    = Event::where('status', 'active')->count();
        $totalUsers     = User::where('role_id', 2)->count();

        // Ingresos totales
        $ingresos = Ticket::where('status', '!=', 'cancelled')
            ->with('ticketType')
            ->get()
            ->sum(fn($t) => $t->ticketType?->price ?? 0);

        // Eventos recientes
        $recentEvents = Event::withCount(['tickets as tickets_sold' => function ($q) {
            $q->whereIn('status', ['paid', 'used']);
        }])
        ->orderBy('created_at', 'desc')
        ->limit(5)
        ->get();

        // Ventas por día (últimos 7 días)
        $salesByDay = Ticket::where('status', '!=', 'cancelled')
            ->where('created_at', '>=', now()->subDays(7))
            ->selectRaw("DATE(created_at) as date, COUNT(*) as total")
            ->groupBy('date')
            ->orderBy('date')
            ->get();

        return response()->json([
            'total_tickets'  => $totalTickets,
            'used_tickets'   => $usedTickets,
            'total_events'   => $totalEvents,
            'total_users'    => $totalUsers,
            'total_revenue'  => $ingresos,
            'recent_events'  => $recentEvents,
            'sales_by_day'   => $salesByDay,
        ]);
    }

    // ─── GESTIÓN DE USUARIOS ──────────────────────────────────────────────────
    public function listUsers(Request $request)
    {
        $this->authorizeAdmin($request);

        $users = User::with('role')
                     ->orderBy('created_at', 'desc')
                     ->get();

        return response()->json($users);
    }

    public function toggleUserStatus(Request $request, $id)
    {
        $this->authorizeAdmin($request);

        $user = User::findOrFail($id);

        if ($user->id === $request->user()->id) {
            return response()->json(['message' => 'No puedes desactivar tu propia cuenta'], 422);
        }

        $user->update([
            'status' => $user->status === 'active' ? 'inactive' : 'active'
        ]);

        return response()->json([
            'message' => 'Estado actualizado',
            'user'    => $user->load('role'),
        ]);
    }

    // ─── GESTIÓN DE PROMOCIONES ───────────────────────────────────────────────
    public function listPromotions(Request $request)
    {
        $this->authorizeAdmin($request);

        return response()->json(
            Promotion::with('event')->orderBy('created_at', 'desc')->get()
        );
    }

    public function storePromotion(Request $request)
    {
        $this->authorizeAdmin($request);

        $request->validate([
            'title'               => 'required|string|max:255',
            'description'         => 'nullable|string',
            'code'                => 'nullable|string|unique:promotions,code',
            'discount_percentage' => 'required|numeric|min:0|max:100',
            'start_date'          => 'required|date',
            'end_date'            => 'required|date|after:start_date',
            'event_id'            => 'nullable|exists:events,id',
            'image'               => 'nullable|file|image|max:5120',
        ]);

        $imagePath = null;
        if ($request->hasFile('image')) {
            $imagePath = $request->file('image')->store('promotions', 'public');
        }

        $promo = Promotion::create([
            'event_id'            => $request->event_id,
            'title'               => $request->title,
            'description'         => $request->description,
            'code'                => $request->code ? strtoupper($request->code) : null,
            'discount_percentage' => $request->discount_percentage,
            'start_date'          => $request->start_date,
            'end_date'            => $request->end_date,
            'image'               => $imagePath,
            'is_active'           => true,
        ]);

        return response()->json([
            'message'   => 'Promoción creada',
            'promotion' => $promo->load('event'),
        ], 201);
    }

    public function updatePromotion(Request $request, $id)
    {
        $this->authorizeAdmin($request);

        $promo = Promotion::findOrFail($id);

        $request->validate([
            'title'               => 'sometimes|string|max:255',
            'discount_percentage' => 'sometimes|numeric|min:0|max:100',
            'start_date'          => 'sometimes|date',
            'end_date'            => 'sometimes|date',
            'is_active'           => 'sometimes|boolean',
        ]);

        $promo->update($request->only([
            'title', 'description', 'code', 'discount_percentage',
            'start_date', 'end_date', 'is_active', 'event_id'
        ]));

        return response()->json([
            'message'   => 'Promoción actualizada',
            'promotion' => $promo->load('event'),
        ]);
    }

    public function destroyPromotion(Request $request, $id)
    {
        $this->authorizeAdmin($request);
        Promotion::findOrFail($id)->delete();
        return response()->json(['message' => 'Promoción eliminada']);
    }

    // ─── REPORTES ─────────────────────────────────────────────────────────────
    public function reportByEvent(Request $request, $eventId)
    {
        $this->authorizeAdmin($request);

        $event = Event::with(['ticketTypes'])->findOrFail($eventId);

        $tickets = Ticket::with(['user', 'ticketType', 'attendance'])
                         ->where('event_id', $eventId)
                         ->orderBy('created_at', 'desc')
                         ->get();

        $summary = [
            'total_sold'     => $tickets->whereIn('status', ['paid', 'used'])->count(),
            'total_used'     => $tickets->where('status', 'used')->count(),
            'total_pending'  => $tickets->where('status', 'pending')->count(),
            'total_revenue'  => $tickets->whereIn('status', ['paid', 'used'])
                                        ->sum(fn($t) => $t->ticketType?->price ?? 0),
        ];

        return response()->json([
            'event'   => $event,
            'summary' => $summary,
            'tickets' => $tickets,
        ]);
    }

    public function reportGeneral(Request $request)
    {
        $this->authorizeAdmin($request);

        $events = Event::withCount([
            'tickets as tickets_sold' => fn($q) => $q->whereIn('status', ['paid', 'used']),
            'tickets as tickets_used' => fn($q) => $q->where('status', 'used'),
        ])
        ->with('ticketTypes')
        ->orderBy('event_date', 'desc')
        ->get();

        $events->each(function ($event) {
            $event->revenue = Ticket::where('event_id', $event->id)
                ->whereIn('status', ['paid', 'used'])
                ->with('ticketType')
                ->get()
                ->sum(fn($t) => $t->ticketType?->price ?? 0);
        });

        return response()->json($events);
    }

    // ─── VALIDAR CÓDIGO PROMOCIONAL ───────────────────────────────────────────
    public function validatePromoCode(Request $request)
    {
        $request->validate(['code' => 'required|string']);

        $promo = Promotion::where('code', strtoupper($request->code))
                          ->where('is_active', true)
                          ->where('start_date', '<=', now())
                          ->where('end_date', '>=', now())
                          ->first();

        if (!$promo) {
            return response()->json([
                'valid'   => false,
                'message' => 'Código inválido o expirado',
            ], 404);
        }

        return response()->json([
            'valid'               => true,
            'discount_percentage' => $promo->discount_percentage,
            'title'               => $promo->title,
            'message'             => "¡Descuento del {$promo->discount_percentage}% aplicado!",
        ]);
    }
}
