<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class ModePaiementSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $modes = [
            ['nom' => 'Espèces', 'actif' => true],
            ['nom' => 'Carte Bancaire', 'actif' => true],
            ['nom' => 'Chèque', 'actif' => true],
            ['nom' => 'Virement', 'actif' => true],
        ];

        foreach ($modes as $mode) {
            DB::table('mode_paiements')->updateOrInsert(
                ['nom' => $mode['nom']],
                ['actif' => $mode['actif'], 'created_at' => now(), 'updated_at' => now()]
            );
        }
    }
}
