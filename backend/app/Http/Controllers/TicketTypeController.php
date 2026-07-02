<?php

namespace App\Http\Controllers;

use App\Models\TicketType;
use Illuminate\Http\Request;

class TicketTypeController extends Controller
{
    public function store(Request $request)
    {
        $this->authorizeAdmin($request);

        $request->validate([
            'event_id' => 'required|exists:events,id',
            'name'     => 'required|string|max:100',
            'price'    => 'required|numeric|min:0',
            'stock'    => 'required|integer|min:1',
        ]);

        $type = TicketType::create($request->only(['event_id', 'name', 'price', 'stock']));

        return response()->json(['message' => 'Tipo de ticket creado', 'ticket_type' => $type], 201);
    }

    public function show($id)
    {
        $type = TicketType::with('event')->findOrFail($id);
        return response()->json($type);
    }

    public function update(Request $request, $id)
    {
        $this->authorizeAdmin($request);

        $type = TicketType::findOrFail($id);

        $request->validate([
            'name'  => 'sometimes|string|max:100',
            'price' => 'sometimes|numeric|min:0',
            'stock' => 'sometimes|integer|min:0',
        ]);

        $type->update($request->only(['name', 'price', 'stock']));

        return response()->json(['message' => 'Tipo de ticket actualizado', 'ticket_type' => $type]);
    }

    public function destroy(Request $request, $id)
    {
        $this->authorizeAdmin($request);

        $type = TicketType::findOrFail($id);
        $type->delete();

        return response()->json(['message' => 'Tipo de ticket eliminado']);
    }

    private function authorizeAdmin(Request $request)
    {
        if (!$request->user() || $request->user()->role_id !== 1) {
            abort(403, 'Solo administradores pueden realizar esta acción.');
        }
    }
}