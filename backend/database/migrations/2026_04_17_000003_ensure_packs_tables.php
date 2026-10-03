<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('packs')) {
            Schema::create('packs', function (Blueprint $table) {
                $table->id();
                $table->string('nom', 150)->unique();
                $table->text('description')->nullable();
                $table->decimal('prix_vente', 10, 2)->default(0);
                $table->string('image')->nullable();
                $table->boolean('actif')->default(true);
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('pack_items')) {
            Schema::create('pack_items', function (Blueprint $table) {
                $table->id();
                $table->foreignId('pack_id')->constrained('packs')->cascadeOnDelete();
                $table->foreignId('article_id')->constrained('articles')->restrictOnDelete();
                $table->decimal('quantite', 10, 2)->default(1);
                $table->timestamps();

                $table->unique(['pack_id', 'article_id']);
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('pack_items')) {
            Schema::drop('pack_items');
        }
        if (Schema::hasTable('packs')) {
            Schema::drop('packs');
        }
    }
};

