<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('lignes_commande_vente', function (Blueprint $table) {
            $table->decimal('quantite', 10, 3)->change();
        });

        Schema::table('stock', function (Blueprint $table) {
            $table->decimal('quantite', 10, 3)->change();
            $table->decimal('seuil_min', 10, 3)->change();
        });

        Schema::table('mouvements_stock', function (Blueprint $table) {
            $table->decimal('quantite', 10, 3)->change();
        });

        Schema::table('lignes_commande_achat', function (Blueprint $table) {
            $table->decimal('quantite', 10, 3)->change();
            $table->decimal('quantite_recue', 10, 3)->change();
        });

        Schema::table('sorties', function (Blueprint $table) {
            $table->decimal('quantite', 10, 3)->change();
        });
    }

    public function down(): void
    {
        Schema::table('lignes_commande_vente', function (Blueprint $table) {
            $table->decimal('quantite', 10, 2)->change();
        });

        Schema::table('stock', function (Blueprint $table) {
            $table->decimal('quantite', 10, 2)->change();
            $table->decimal('seuil_min', 10, 2)->change();
        });

        Schema::table('mouvements_stock', function (Blueprint $table) {
            $table->decimal('quantite', 10, 2)->change();
        });

        Schema::table('lignes_commande_achat', function (Blueprint $table) {
            $table->decimal('quantite', 10, 2)->change();
            $table->decimal('quantite_recue', 10, 2)->change();
        });

        Schema::table('sorties', function (Blueprint $table) {
            $table->decimal('quantite', 10, 2)->change();
        });
    }
};
