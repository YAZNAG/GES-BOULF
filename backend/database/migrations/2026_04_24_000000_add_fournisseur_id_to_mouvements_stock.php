<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('mouvements_stock', function (Blueprint $table) {
            if (!Schema::hasColumn('mouvements_stock', 'fournisseur_id')) {
                $table->foreignId('fournisseur_id')
                      ->nullable()
                      ->after('article_id')
                      ->constrained('fournisseurs')
                      ->nullOnDelete();
            }
            
            // Also ensure quantite is decimal(10,3) here just in case
            $table->decimal('quantite', 10, 3)->change();
        });
    }

    public function down(): void
    {
        Schema::table('mouvements_stock', function (Blueprint $table) {
            $table->dropForeign(['fournisseur_id']);
            $table->dropColumn('fournisseur_id');
        });
    }
};
