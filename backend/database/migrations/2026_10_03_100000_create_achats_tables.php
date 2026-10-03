<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Module Achats : fiche fournisseur enrichie + crédit fournisseur, bons de commande,
 * bons de réception (entrées de stock, prix d'achat) et règlements fournisseurs.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('fournisseurs', function (Blueprint $table) {
            $table->string('code', 30)->nullable()->after('id');
            $table->string('contact', 120)->nullable()->after('nom');
            $table->string('ville', 80)->nullable()->after('adresse');
            $table->string('ice', 20)->nullable()->after('ville');
            $table->string('rc', 30)->nullable()->after('ice');
            $table->decimal('solde', 12, 2)->default(0)->after('rc');
            $table->decimal('plafond_credit', 12, 2)->nullable()->after('solde');
            $table->unsignedSmallInteger('delai_paiement')->nullable()->after('plafond_credit');
            $table->text('note')->nullable()->after('delai_paiement');
        });

        // Statuts sans accents et nouveau statut « partielle » (réception partielle).
        Schema::table('commandes_achat', function (Blueprint $table) {
            $table->string('statut', 20)->default('brouillon')->change();
        });
        DB::table('commandes_achat')->where('statut', 'confirmée')->update(['statut' => 'confirmee']);
        DB::table('commandes_achat')->where('statut', 'reçue')->update(['statut' => 'recue']);
        DB::table('commandes_achat')->where('statut', 'annulée')->update(['statut' => 'annulee']);

        Schema::table('commandes_achat', function (Blueprint $table) {
            $table->string('numero', 30)->nullable()->unique()->after('id');
            $table->date('date_prevue')->nullable()->after('date_commande');
            $table->decimal('total', 12, 2)->default(0)->after('date_reception');
        });
        Schema::table('lignes_commande_achat', function (Blueprint $table) {
            $table->decimal('quantite', 10, 3)->change();
            $table->decimal('quantite_recue', 10, 3)->default(0)->change();
            $table->decimal('prix_unitaire', 10, 2)->default(0)->change();
        });

        Schema::create('receptions', function (Blueprint $table) {
            $table->id();
            $table->string('numero', 30)->unique();
            $table->foreignId('fournisseur_id')->constrained('fournisseurs')->restrictOnDelete();
            $table->foreignId('commande_achat_id')->nullable()->constrained('commandes_achat')->nullOnDelete();
            $table->date('date_reception');
            $table->string('reference_fournisseur', 60)->nullable(); // n° BL ou facture du fournisseur
            $table->decimal('total', 12, 2)->default(0);
            $table->decimal('montant_paye', 12, 2)->default(0);
            $table->string('mode_paiement', 30)->nullable();
            $table->text('note')->nullable();
            $table->foreignId('utilisateur_id')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->timestamps();
            $table->index('date_reception');
        });

        Schema::create('lignes_reception', function (Blueprint $table) {
            $table->id();
            $table->foreignId('reception_id')->constrained('receptions')->cascadeOnDelete();
            $table->foreignId('article_id')->constrained('articles')->restrictOnDelete();
            $table->foreignId('ligne_commande_achat_id')->nullable()->constrained('lignes_commande_achat')->nullOnDelete();
            $table->decimal('quantite', 10, 3);
            $table->decimal('prix_achat', 10, 2);
            $table->decimal('prix_vente', 10, 2)->nullable(); // nouveau prix de vente fixé à la réception
            $table->timestamps();
        });

        Schema::create('paiements_fournisseur', function (Blueprint $table) {
            $table->id();
            $table->foreignId('fournisseur_id')->constrained('fournisseurs')->restrictOnDelete();
            $table->foreignId('reception_id')->nullable()->constrained('receptions')->nullOnDelete();
            $table->decimal('montant', 12, 2);
            $table->string('mode', 30)->default('especes');
            $table->date('date_paiement');
            $table->string('reference', 60)->nullable(); // n° de chèque, de virement…
            $table->text('note')->nullable();
            $table->foreignId('utilisateur_id')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('paiements_fournisseur');
        Schema::dropIfExists('lignes_reception');
        Schema::dropIfExists('receptions');
        Schema::table('commandes_achat', function (Blueprint $table) {
            $table->dropUnique(['numero']);
            $table->dropColumn(['numero', 'date_prevue', 'total']);
        });
        Schema::table('fournisseurs', function (Blueprint $table) {
            $table->dropColumn(['code', 'contact', 'ville', 'ice', 'rc', 'solde', 'plafond_credit', 'delai_paiement', 'note']);
        });
    }
};
