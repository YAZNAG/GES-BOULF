<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Clients de passage : vente payée en partie sans fiche client.
 * - nom / téléphone facultatifs saisis à la caisse pour retrouver la personne ;
 * - encaissements ultérieurs du reste (historique).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('ventes', function (Blueprint $table) {
            $table->string('nom_passage', 120)->nullable()->after('client_id');
            $table->string('telephone_passage', 20)->nullable()->after('nom_passage');
        });

        Schema::create('encaissements_passage', function (Blueprint $table) {
            $table->id();
            $table->foreignId('vente_id')->constrained('ventes')->cascadeOnDelete();
            $table->decimal('montant', 12, 2);
            $table->string('mode', 30)->default('especes');
            $table->text('note')->nullable();
            $table->foreignId('utilisateur_id')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('encaissements_passage');
        Schema::table('ventes', function (Blueprint $table) {
            $table->dropColumn(['nom_passage', 'telephone_passage']);
        });
    }
};
