<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Inventaires (comptage physique du stock) et charges (dépenses du magasin).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('inventaires', function (Blueprint $table) {
            $table->id();
            $table->string('numero', 30)->unique();
            $table->string('libelle', 150);
            $table->string('statut', 20)->default('en_cours'); // en_cours, valide, annule
            $table->foreignId('famille_id')->nullable()->constrained('familles')->nullOnDelete();
            $table->foreignId('categorie_id')->nullable()->constrained('categories')->nullOnDelete();
            $table->timestamp('valide_le')->nullable();
            $table->text('note')->nullable();
            $table->foreignId('utilisateur_id')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->foreignId('valide_par')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->timestamps();
            $table->index('statut');
        });

        Schema::create('lignes_inventaire', function (Blueprint $table) {
            $table->id();
            $table->foreignId('inventaire_id')->constrained('inventaires')->cascadeOnDelete();
            $table->foreignId('article_id')->constrained('articles')->restrictOnDelete();
            $table->decimal('quantite_theorique', 12, 3)->default(0); // stock au moment du comptage
            $table->decimal('quantite_comptee', 12, 3)->default(0);
            $table->decimal('prix_achat', 10, 2)->default(0);
            $table->foreignId('utilisateur_id')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->timestamps();
            $table->unique(['inventaire_id', 'article_id']);
        });

        Schema::create('categories_charges', function (Blueprint $table) {
            $table->id();
            $table->string('nom', 80)->unique();
            $table->string('icone', 40)->nullable();
            $table->string('couleur', 9)->nullable();
            $table->boolean('actif')->default(true);
            $table->timestamps();
        });

        Schema::create('charges', function (Blueprint $table) {
            $table->id();
            $table->foreignId('categorie_charge_id')->constrained('categories_charges')->restrictOnDelete();
            $table->string('libelle', 150);
            $table->decimal('montant', 12, 2);
            $table->date('date_charge');
            $table->string('mode_paiement', 30)->default('especes');
            $table->string('reference', 60)->nullable();      // n° de facture, de chèque…
            $table->string('beneficiaire', 120)->nullable();
            $table->string('piece')->nullable();               // photo du justificatif
            $table->text('note')->nullable();
            $table->foreignId('utilisateur_id')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->timestamps();
            $table->index('date_charge');
        });

        $now = now();
        DB::table('categories_charges')->insert(array_map(fn ($c) => [
            'nom' => $c[0], 'icone' => $c[1], 'couleur' => $c[2], 'actif' => true, 'created_at' => $now, 'updated_at' => $now,
        ], [
            ['Loyer', 'home', '#7C3AED'],
            ['Électricité', 'bolt', '#F59E0B'],
            ['Eau', 'water', '#0EA5E9'],
            ['Salaires', 'people', '#2563EB'],
            ['Transport & carburant', 'truck', '#0D9488'],
            ['Téléphone & internet', 'wifi', '#6366F1'],
            ['Entretien & réparations', 'build', '#64748B'],
            ['Fournitures & emballages', 'inventory', '#16A34A'],
            ['Impôts & taxes', 'gavel', '#DC2626'],
            ['Banque & frais', 'bank', '#0F172A'],
            ['Autres', 'more', '#94A3B8'],
        ]));
    }

    public function down(): void
    {
        Schema::dropIfExists('charges');
        Schema::dropIfExists('categories_charges');
        Schema::dropIfExists('lignes_inventaire');
        Schema::dropIfExists('inventaires');
    }
};
