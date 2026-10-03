<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            $table->string('name_ar', 100)->nullable()->after('nom');
            $table->string('name_fr', 100)->nullable()->after('name_ar');
        });

        Schema::table('sous_categories', function (Blueprint $table) {
            $table->string('name_ar', 100)->nullable()->after('nom');
            $table->string('name_fr', 100)->nullable()->after('name_ar');
        });

        Schema::table('articles', function (Blueprint $table) {
            $table->string('name_ar', 150)->nullable()->after('nom');
            $table->string('name_fr', 150)->nullable()->after('name_ar');
        });
    }

    public function down(): void
    {
        Schema::table('articles', function (Blueprint $table) {
            $table->dropColumn(['name_ar', 'name_fr']);
        });

        Schema::table('sous_categories', function (Blueprint $table) {
            $table->dropColumn(['name_ar', 'name_fr']);
        });

        Schema::table('categories', function (Blueprint $table) {
            $table->dropColumn(['name_ar', 'name_fr']);
        });
    }
};
