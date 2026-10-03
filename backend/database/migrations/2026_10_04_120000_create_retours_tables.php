<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Retours clients (bon RC-…) et retours fournisseurs (bon RF-…).
 * La table historique `retours` (une ligne par article retourné) est complétée : numéro de bon,
 * remise en stock ou non, mode de remboursement.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('retours', function (Blueprint $table) {
            $table->string('numero', 30)->nullable()->after('id')->index();
            $table->boolean('en_stock')->default(true)->after('montant');      // article remis en rayon
            $table->string('remboursement', 20)->default('especes')->after('en_stock'); // especes, credit, aucun
        });

        Schema::create('retours_fournisseur', function (Blueprint $table) {
            $table->id();
            $table->string('numero', 30)->unique();
            $table->foreignId('fournisseur_id')->constrained('fournisseurs')->restrictOnDelete();
            $table->foreignId('reception_id')->nullable()->constrained('receptions')->nullOnDelete();
            $table->date('date_retour');
            $table->string('motif', 150)->nullable();
            $table->decimal('total', 12, 2)->default(0);
            // avoir : déduit du crédit fournisseur ; remboursement : le fournisseur rend l'argent.
            $table->string('reglement', 20)->default('avoir');
            $table->text('note')->nullable();
            $table->foreignId('utilisateur_id')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('lignes_retour_fournisseur', function (Blueprint $table) {
            $table->id();
            $table->foreignId('retour_fournisseur_id')->constrained('retours_fournisseur')->cascadeOnDelete();
            $table->foreignId('article_id')->constrained('articles')->restrictOnDelete();
            $table->decimal('quantite', 10, 3);
            $table->decimal('prix_achat', 10, 2);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('lignes_retour_fournisseur');
        Schema::dropIfExists('retours_fournisseur');
        Schema::table('retours', function (Blueprint $table) {
            $table->dropColumn(['numero', 'en_stock', 'remboursement']);
        });
    }
};
