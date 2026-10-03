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
        Schema::table('commandes_vente', function (Blueprint $table) {
            $table->string('numero', 50)->nullable()->after('id')->unique();
            $table->string('type_commande', 50)->default('livraison')->after('numero');
            $table->decimal('total', 10, 2)->default(0)->after('note');

            // To support 'en_cours' and 'livre' which are in the UI, we might just use string
            // but we can't easily change ENUM with SQLite or MySQL without doctrine/dbal.
            // Since this is MySQL (DB_CONNECTION=mysql in .env), we can do raw query or add new enum values.
            // Actually, modifying an enum column requires doctrine/dbal. 
            // Instead, I'll just change the column type to string.
        });

        // Modify statut column to be string instead of enum to avoid issues, or just add the new statuses if it's MySQL.
        // It's safer to just change it to string so we can use any status.
        \Illuminate\Support\Facades\DB::statement("ALTER TABLE commandes_vente MODIFY COLUMN statut VARCHAR(50) DEFAULT 'en_attente'");
        \Illuminate\Support\Facades\DB::statement("ALTER TABLE commandes_vente MODIFY COLUMN type_commande VARCHAR(50) DEFAULT 'livraison'");
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('commandes_vente', function (Blueprint $table) {
            $table->dropColumn(['numero', 'type_commande', 'total']);
        });

        \Illuminate\Support\Facades\DB::statement("ALTER TABLE commandes_vente MODIFY COLUMN statut ENUM('en_attente', 'confirmée', 'payée', 'annulée') DEFAULT 'en_attente'");
    }
};
