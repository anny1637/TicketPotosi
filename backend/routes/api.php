<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\EventController;
use App\Http\Controllers\TicketController;
use App\Http\Controllers\TicketTypeController;
use App\Http\Controllers\AdminController;

// ─── RUTAS PÚBLICAS ────────────────────────────────────────────────────────────
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login',    [AuthController::class, 'login']);

// Eventos públicos (activos)
Route::get('/events',      [EventController::class, 'index']);
Route::get('/events/{id}', [EventController::class, 'show']);

// Promociones públicas activas
Route::get('/promotions/active', function () {
    $promos = \App\Models\Promotion::where('is_active', true)
                ->where('start_date', '<=', now())
                ->where('end_date', '>=', now())
                ->with('event')
                ->get();
    return response()->json($promos);
});

// Validar código de promoción (público, para usar al comprar)
Route::post('/promotions/validate', [AdminController::class, 'validatePromoCode']);

// ─── RUTAS PROTEGIDAS ─────────────────────────────────────────────────────────
Route::middleware('auth:sanctum')->group(function () {

    // ── AUTH ──────────────────────────────────────────────────────────────────
    Route::post('/logout',           [AuthController::class, 'logout']);
    Route::get('/profile',           [AuthController::class, 'profile']);
    Route::put('/profile',           [AuthController::class, 'updateProfile']);
    Route::put('/change-password',   [AuthController::class, 'changePassword']);

    // ── TICKETS (Cliente) ─────────────────────────────────────────────────────
    Route::post('/tickets/purchase',    [TicketController::class, 'purchase']);
    Route::get('/tickets/my-tickets',   [TicketController::class, 'myTickets']);
    Route::get('/tickets/{id}',         [TicketController::class, 'show']);

    // ── QR SCANNER (Admin o escáner) ──────────────────────────────────────────
    Route::post('/tickets/validate-qr', [TicketController::class, 'validateQR']);

    // ── ADMIN: EVENTOS CRUD ───────────────────────────────────────────────────
    Route::post('/events',        [EventController::class, 'store']);
    Route::post('/events/{id}',   [EventController::class, 'update']); // POST con _method=PUT para multipart
    Route::put('/events/{id}',    [EventController::class, 'update']);
    Route::delete('/events/{id}', [EventController::class, 'destroy']);

    // ── ADMIN: TICKET TYPES ───────────────────────────────────────────────────
    Route::post('/ticket-types',       [TicketTypeController::class, 'store']);
    Route::get('/ticket-types/{id}',   [TicketTypeController::class, 'show']);
    Route::put('/ticket-types/{id}',   [TicketTypeController::class, 'update']);
    Route::delete('/ticket-types/{id}',[TicketTypeController::class, 'destroy']);

    // ── ADMIN: DASHBOARD & ESTADÍSTICAS ──────────────────────────────────────
    Route::get('/admin/dashboard',          [AdminController::class, 'dashboard']);
    Route::get('/admin/tickets',            [TicketController::class, 'allTickets']);
    Route::get('/admin/users',              [AdminController::class, 'listUsers']);
    Route::put('/admin/users/{id}/toggle',  [AdminController::class, 'toggleUserStatus']);

    // ── ADMIN: PROMOCIONES ────────────────────────────────────────────────────
    Route::get('/admin/promotions',         [AdminController::class, 'listPromotions']);
    Route::post('/admin/promotions',        [AdminController::class, 'storePromotion']);
    Route::put('/admin/promotions/{id}',    [AdminController::class, 'updatePromotion']);
    Route::delete('/admin/promotions/{id}', [AdminController::class, 'destroyPromotion']);

    // ── ADMIN: REPORTES ───────────────────────────────────────────────────────
    Route::get('/admin/reports/general',        [AdminController::class, 'reportGeneral']);
    Route::get('/admin/reports/event/{eventId}', [AdminController::class, 'reportByEvent']);
});
