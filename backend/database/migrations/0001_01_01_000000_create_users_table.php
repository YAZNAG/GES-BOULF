<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('roles', function (Blueprint $table) {
            $table->id();
            $table->string('nom', 50)->unique();
            $table->text('description')->nullable();
            $table->timestamps();
        });

        Schema::create('utilisateurs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('role_id')->constrained('roles')->restrictOnDelete();
            $table->string('nom', 100);
            $table->string('prenom', 100)->nullable();
            $table->string('email', 100)->unique();
            $table->string('mot_de_passe');
            $table->boolean('actif')->default(true);
            $table->timestamps();
        });

        Schema::create('categories', function (Blueprint $table) {
            $table->id();
            $table->string('nom', 100);
            $table->text('description')->nullable();
            $table->timestamps();
        });

        Schema::create('sous_categories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('categorie_id')->constrained('categories')->restrictOnDelete();
            $table->string('nom', 100);
            $table->text('description')->nullable();
            $table->timestamps();
        });

        Schema::create('articles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sous_categorie_id')->constrained('sous_categories')->restrictOnDelete();
            $table->string('code_article', 50)->unique();
            $table->string('nom', 150);
            $table->text('description')->nullable();
            $table->string('unite', 20)->default('pièce');
            $table->string('image')->nullable();
            $table->boolean('actif')->default(true);
            $table->timestamps();
        });

        Schema::create('prix_articles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('article_id')->unique()->constrained('articles')->cascadeOnDelete();
            $table->decimal('prix_achat', 10, 2)->default(0);
            $table->decimal('prix_vente', 10, 2)->default(0);
            $table->decimal('prix_gros', 10, 2)->nullable();
            $table->decimal('prix_promo', 10, 2)->nullable();
            $table->timestamps();
        });

        Schema::create('stock', function (Blueprint $table) {
            $table->id();
            $table->foreignId('article_id')->unique()->constrained('articles')->cascadeOnDelete();
            $table->decimal('quantite', 10, 2)->default(0);
            $table->decimal('seuil_min', 10, 2)->default(0);
            $table->timestamps();
        });

        Schema::create('fournisseurs', function (Blueprint $table) {
            $table->id();
            $table->string('nom', 150);
            $table->string('telephone', 20)->nullable();
            $table->string('email', 100)->nullable();
            $table->text('adresse')->nullable();
            $table->boolean('actif')->default(true);
            $table->timestamps();
        });

        Schema::create('commandes_achat', function (Blueprint $table) {
            $table->id();
            $table->foreignId('fournisseur_id')->nullable()->constrained('fournisseurs')->nullOnDelete();
            $table->enum('statut', ['brouillon', 'confirmée', 'reçue', 'annulée'])->default('brouillon');
            $table->date('date_commande');
            $table->date('date_reception')->nullable();
            $table->text('note')->nullable();
            $table->foreignId('utilisateur_id')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('lignes_commande_achat', function (Blueprint $table) {
            $table->id();
            $table->foreignId('commande_achat_id')->constrained('commandes_achat')->cascadeOnDelete();
            $table->foreignId('article_id')->constrained('articles')->restrictOnDelete();
            $table->decimal('quantite', 10, 2);
            $table->decimal('quantite_recue', 10, 2)->default(0);
            $table->decimal('prix_unitaire', 10, 2);
            $table->timestamps();
        });

        Schema::create('clients', function (Blueprint $table) {
            $table->id();
            $table->string('nom', 150);
            $table->string('telephone', 20)->nullable();
            $table->string('email', 100)->nullable();
            $table->text('adresse')->nullable();
            $table->enum('type_client', ['detail', 'gros'])->default('detail');
            $table->boolean('actif')->default(true);
            $table->timestamps();
        });

        Schema::create('commandes_vente', function (Blueprint $table) {
            $table->id();
            $table->foreignId('client_id')->nullable()->constrained('clients')->nullOnDelete();
            $table->enum('statut', ['en_attente', 'confirmée', 'payée', 'annulée'])->default('en_attente');
            $table->timestamp('date_commande')->useCurrent();
            $table->text('note')->nullable();
            $table->foreignId('utilisateur_id')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('lignes_commande_vente', function (Blueprint $table) {
            $table->id();
            $table->foreignId('commande_vente_id')->constrained('commandes_vente')->cascadeOnDelete();
            $table->foreignId('article_id')->constrained('articles')->restrictOnDelete();
            $table->decimal('quantite', 10, 2);
            $table->decimal('prix_unitaire', 10, 2);
            $table->decimal('remise', 5, 2)->default(0);
            $table->timestamps();
        });

        Schema::create('ventes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('commande_vente_id')->unique()->constrained('commandes_vente')->cascadeOnDelete();
            $table->foreignId('client_id')->nullable()->constrained('clients')->nullOnDelete();
            $table->decimal('montant_total', 10, 2);
            $table->decimal('montant_remise', 10, 2)->default(0);
            $table->decimal('montant_paye', 10, 2);
            $table->string('mode_paiement', 50)->default('espèces');
            $table->timestamp('date_vente')->useCurrent();
            $table->foreignId('utilisateur_id')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('promotions', function (Blueprint $table) {
            $table->id();
            $table->string('name', 150);
            $table->enum('type', ['pourcentage', 'montant_fixe']);
            $table->decimal('value', 10, 2);
            $table->date('start_date');
            $table->date('end_date');
            $table->enum('target_type', ['article', 'category', 'client']);
            $table->unsignedBigInteger('target_id');
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->index(['target_type', 'target_id']);
        });

        Schema::create('mouvements_stock', function (Blueprint $table) {
            $table->id();
            $table->foreignId('article_id')->constrained('articles')->restrictOnDelete();
            $table->enum('type_mouvement', ['entree', 'sortie']);
            $table->enum('motif', ['achat', 'vente', 'perte', 'don', 'retour', 'ajustement']);
            $table->decimal('quantite', 10, 2);
            $table->unsignedBigInteger('reference_id')->nullable();
            $table->string('reference_type', 50)->nullable();
            $table->foreignId('utilisateur_id')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->text('note')->nullable();
            $table->timestamps();

            $table->index(['reference_type', 'reference_id']);
        });

        Schema::create('sorties', function (Blueprint $table) {
            $table->id();
            $table->foreignId('article_id')->constrained('articles')->cascadeOnDelete();
            $table->enum('motif', ['perte', 'don', 'retour', 'ajustement']);
            $table->decimal('quantite', 10, 2);
            $table->text('note')->nullable();
            $table->foreignId('utilisateur_id')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('historique_actions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('utilisateur_id')->nullable()->constrained('utilisateurs')->nullOnDelete();
            $table->string('action', 50);
            $table->string('table_cible', 50);
            $table->unsignedBigInteger('enregistrement_id')->nullable();
            $table->json('details')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('historique_actions');
        Schema::dropIfExists('mouvements_stock');
        Schema::dropIfExists('promotions');
        Schema::dropIfExists('ventes');
        Schema::dropIfExists('lignes_commande_vente');
        Schema::dropIfExists('commandes_vente');
        Schema::dropIfExists('clients');
        Schema::dropIfExists('lignes_commande_achat');
        Schema::dropIfExists('commandes_achat');
        Schema::dropIfExists('fournisseurs');
        Schema::dropIfExists('stock');
        Schema::dropIfExists('prix_articles');
        Schema::dropIfExists('articles');
        Schema::dropIfExists('sous_categories');
        Schema::dropIfExists('categories');
        Schema::dropIfExists('utilisateurs');
        Schema::dropIfExists('roles');
        Schema::dropIfExists('password_reset_tokens');
        Schema::dropIfExists('sessions');
        Schema::dropIfExists('users');
    }
};
