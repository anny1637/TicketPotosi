<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class UserSeeder extends Seeder
{
    public function run(): void
    {
        DB::table('users')->insert([
            [
                'name'       => 'Administrador',
                'email'      => 'admin@ticketpotosi.com',
                'password'   => Hash::make('admin123'),
                'phone'      => '70000000',
                'role_id'    => 1, // Admin
                'photo'      => null,
                'status'     => 'active',
                'created_at' => now(),
                'updated_at' => now(),
            ]
        ]);
    }
}