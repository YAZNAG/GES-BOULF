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
        Schema::table('articles', function (Blueprint $table) {
            $table->dropForeign(['sous_categorie_id']);
            $table->renameColumn('sous_categorie_id', 'sub_categorie_id');
            $table->foreign('sub_categorie_id')->references('id')->on('sub_categories')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('articles', function (Blueprint $table) {
            $table->dropForeign(['sub_categorie_id']);
            $table->renameColumn('sub_categorie_id', 'sous_categorie_id');
            $table->foreign('sous_categorie_id')->references('id')->on('sous_categories')->onDelete('cascade');
        });
    }
};
