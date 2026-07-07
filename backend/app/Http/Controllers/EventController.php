<?php

namespace App\Http\Controllers;

use App\Models\Event;
use App\Models\TicketType;
use App\Models\Presale;
use App\Models\Ticket;
use App\Models\Payment;
use App\Models\Attendance;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\DB;

class EventController extends Controller
{
    // LISTAR EVENTOS (público)
    public function index(Request $request)
    {
        $query = Event::with(['ticketTypes', 'presale'])
                      ->orderBy('event_date', 'asc');

        // Filtro por categoría
        if ($request->has('category') && $request->category !== 'Todos') {
            $query->where('category', $request->category);
        }

        // Solo eventos activos para usuarios normales
        if (!$request->user() || $request->user()->role_id !== 1) {
            $query->where('status', 'active');
        }

        $events = $query->get();

        // Agregar precio actual (considerando preventa)
        $events->each(function ($event) {
            $event->ticketTypes->each(function ($type) use ($event) {
                $presale = Presale::where('event_id', $event->id)
                    ->where(function ($q) use ($type) {
                        $q->where('ticket_type_id', $type->id)
                          ->orWhereNull('ticket_type_id');
                    })
                    ->where('is_active', true)
                    ->where('start_date', '<=', now())
                    ->where('end_date', '>=', now())
                    ->first();

                $type->current_price     = $presale ? $presale->presale_price : $type->price;
                $type->is_presale        = $presale !== null;
                $type->presale_end_date  = $presale ? $presale->end_date : null;
            });
        });

        return response()->json($events);
    }

    // VER UN EVENTO (público)
    public function show($id)
    {
        $event = Event::with(['ticketTypes', 'presale', 'artists'])
                      ->findOrFail($id);

        // Agregar precio actual por tipo
        $event->ticketTypes->each(function ($type) use ($event) {
            $presale = Presale::where('event_id', $event->id)
                ->where(function ($q) use ($type) {
                    $q->where('ticket_type_id', $type->id)
                      ->orWhereNull('ticket_type_id');
                })
                ->where('is_active', true)
                ->where('start_date', '<=', now())
                ->where('end_date', '>=', now())
                ->first();

            $type->current_price     = $presale ? $presale->presale_price : $type->price;
            $type->is_presale        = $presale !== null;
            $type->presale_end_date  = $presale ? $presale->end_date : null;
        });

        return response()->json($event);
    }

    // CREAR EVENTO (Admin)
    public function store(Request $request)
    {
        $this->authorizeAdmin($request);

        $request->validate([
            'title'             => 'required|string|max:255',
            'description'       => 'required|string',
            'location'          => 'required|string',
            'event_date'        => 'required|date',
            'capacity'          => 'required|integer|min:1',
            'organizer'         => 'nullable|string|max:255',
            'category'          => 'nullable|string|max:100',
            'image'             => 'nullable|file|image|max:5120',
            'video'             => 'nullable|file|mimes:mp4,mov,avi,webm|max:102400',
            'ticket_types'      => 'required|array|min:1',
            'ticket_types.*.name'  => 'required|string',
            'ticket_types.*.price' => 'required|numeric|min:0',
            'ticket_types.*.stock' => 'required|integer|min:1',
            // Preventa opcional
            'presale_start'     => 'nullable|date',
            'presale_end'       => 'nullable|date|after:presale_start',
            'presale_price'     => 'nullable|numeric|min:0',
        ]);

        $imagePath = null;
        $videoPath = null;

        if ($request->hasFile('image')) {
            $imagePath = $request->file('image')->store('events/images', 'public');
        }
        if ($request->hasFile('video')) {
            $videoPath = $request->file('video')->store('events/videos', 'public');
        }

        $event = Event::create([
            'title'             => $request->title,
            'description'       => $request->description,
            'location'          => $request->location,
            'event_date'        => $request->event_date,
            'organizer'         => $request->organizer ?? 'Gobernación de Potosí',
            'category'          => $request->category ?? 'General',
            'capacity'          => $request->capacity,
            'tickets_available' => $request->capacity,
            'image'             => $imagePath,
            'video'             => $videoPath,
            'status'            => 'active',
        ]);

        // Crear tipos de ticket
        foreach ($request->ticket_types as $tt) {
            TicketType::create([
                'event_id' => $event->id,
                'name'     => $tt['name'],
                'price'    => $tt['price'],
                'stock'    => $tt['stock'],
            ]);
        }

        // Crear preventa si se especificó
        if ($request->presale_start && $request->presale_end && $request->presale_price) {
            Presale::create([
                'event_id'      => $event->id,
                'start_date'    => $request->presale_start,
                'end_date'      => $request->presale_end,
                'presale_price' => $request->presale_price,
                'is_active'     => true,
            ]);
        }

        return response()->json([
            'message' => 'Evento creado correctamente',
            'event'   => $event->load(['ticketTypes', 'presale']),
        ], 201);
    }

    // EDITAR EVENTO (Admin)
    public function update(Request $request, $id)
    {
        $this->authorizeAdmin($request);

        $event = Event::findOrFail($id);

        $request->validate([
            'title'       => 'sometimes|string|max:255',
            'description' => 'sometimes|string',
            'location'    => 'sometimes|string',
            'event_date'  => 'sometimes|date',
            'organizer'   => 'nullable|string|max:255',
            'category'    => 'nullable|string|max:100',
            'status'      => 'sometimes|in:active,inactive,cancelled',
            'image'       => 'nullable|file|image|max:5120',
            'video'       => 'nullable|file|mimes:mp4,mov,avi,webm|max:102400',
        ]);

        $data = $request->only([
            'title', 'description', 'location', 'event_date',
            'organizer', 'category', 'status', 'capacity'
        ]);

        if ($request->hasFile('image')) {
            if ($event->image) Storage::disk('public')->delete($event->image);
            $data['image'] = $request->file('image')->store('events/images', 'public');
        }
        if ($request->hasFile('video')) {
            if ($event->video) Storage::disk('public')->delete($event->video);
            $data['video'] = $request->file('video')->store('events/videos', 'public');
        }

        $event->update($data);

        // Actualizar tipos de ticket
        if ($request->has('ticket_types') && is_array($request->ticket_types)) {
            $keepIds = [];
            foreach ($request->ticket_types as $ttData) {
                if (is_string($ttData)) {
                    $ttData = json_decode($ttData, true);
                }
                if (!$ttData || !isset($ttData['name'])) continue;
                
                $tt = TicketType::updateOrCreate(
                    [
                        'event_id' => $event->id,
                        'name'     => $ttData['name'],
                    ],
                    [
                        'price'    => $ttData['price'] ?? 0,
                        'stock'    => $ttData['stock'] ?? 100,
                    ]
                );
                $keepIds[] = $tt->id;
            }
            
            // Eliminar tipos de entrada obsoletos (que no tengan ventas asociadas)
            $typesToDelete = TicketType::where('event_id', $event->id)->whereNotIn('id', $keepIds)->get();
            foreach ($typesToDelete as $typeToDelete) {
                $hasTickets = Ticket::where('ticket_type_id', $typeToDelete->id)->exists();
                if (!$hasTickets) {
                    $typeToDelete->delete();
                }
            }
        }

        // Actualizar preventa
        if ($request->filled('presale_start') && $request->filled('presale_end') && $request->filled('presale_price')) {
            Presale::updateOrCreate(
                ['event_id' => $event->id],
                [
                    'start_date'    => $request->presale_start,
                    'end_date'      => $request->presale_end,
                    'presale_price' => $request->presale_price,
                    'is_active'     => true,
                ]
            );
        } else if ($request->has('presale_price') && empty($request->presale_price)) {
            Presale::where('event_id', $event->id)->delete();
        }

        return response()->json([
            'message' => 'Evento actualizado correctamente',
            'event'   => $event->load(['ticketTypes', 'presale']),
        ]);
    }

    // ELIMINAR EVENTO (Admin)
    public function destroy(Request $request, $id)
    {
        $this->authorizeAdmin($request);

        $event = Event::findOrFail($id);

        // Eliminar archivos
        if ($event->image) Storage::disk('public')->delete($event->image);
        if ($event->video) Storage::disk('public')->delete($event->video);

        DB::transaction(function () use ($event) {
            // Eliminar pagos y asistencias asociadas a los tickets de este evento
            $ticketIds = Ticket::where('event_id', $event->id)->pluck('id');
            Payment::whereIn('ticket_id', $ticketIds)->delete();
            Attendance::whereIn('ticket_id', $ticketIds)->delete();
            
            // Eliminar tickets
            Ticket::where('event_id', $event->id)->delete();
            
            // Eliminar tipos de ticket
            TicketType::where('event_id', $event->id)->delete();
            
            // Eliminar preventas
            Presale::where('event_id', $event->id)->delete();
            
            // Eliminar evento
            $event->delete();
        });

        return response()->json(['message' => 'Evento y todos sus registros asociados eliminados correctamente']);
    }

    // Validar que el usuario es admin
    private function authorizeAdmin(Request $request)
    {
        if (!$request->user() || $request->user()->role_id !== 1) {
            abort(403, 'Acceso denegado. Solo administradores.');
        }
    }
}