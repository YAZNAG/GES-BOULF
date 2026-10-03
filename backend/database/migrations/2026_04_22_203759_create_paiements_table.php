<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('paiements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('client_id')->constrained('clients')->onDelete('cascade');
            $table->foreignId('vente_id')->nullable()->constrained('ventes')->onDelete('set null');
            $table->decimal('montant', 15, 2);
            $table->string('mode', 50)->default('espèces');
            $table->text('note')->nullable();
            $table->foreignId('utilisateur_id')->nullable()->constrained('utilisateurs')->onDelete('set null');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('paiements');
    }
};
