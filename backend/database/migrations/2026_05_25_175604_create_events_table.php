<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('events', function (Blueprint $table) {
            $table->id();
            $table->string('title');
            $table->text('description');
            $table->string('location');
            $table->dateTime('event_date');
            $table->string('image')->nullable();
            $table->string('video')->nullable();
            $table->string('organizer')->default('Gobernación de Potosí');
            $table->string('organizer_logo')->nullable();
            $table->string('banner_image')->nullable();
            $table->string('category')->default('General');
            $table->enum('status', ['active', 'inactive', 'cancelled'])->default('active');
            $table->integer('capacity');
            $table->integer('tickets_available');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('events');
    }
};