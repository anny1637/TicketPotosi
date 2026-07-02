<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class RoleSeeder extends Seeder
{
    public function run(): void
    {
        DB::table('roles')->insert([
            ['name' => 'Admin',    'created_at' => now(), 'updated_at' => now()],
            ['name' => 'Cliente',  'created_at' => now(), 'updated_at' => now()],
            ['name' => 'Scanner',  'created_at' => now(), 'updated_at' => now()],
        ]);
    }
}
