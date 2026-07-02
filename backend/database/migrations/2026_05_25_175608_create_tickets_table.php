<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tickets', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users');
            $table->foreignId('event_id')->constrained('events');
            $table->foreignId('ticket_type_id')->constrained('ticket_types');
            $table->string('ticket_code')->unique();
            $table->uuid('qr_token')->unique();
            $table->enum('status', ['pending', 'paid', 'used', 'cancelled', 'expired'])
                  ->default('pending');
            $table->dateTime('purchase_date')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tickets');
    }
};
