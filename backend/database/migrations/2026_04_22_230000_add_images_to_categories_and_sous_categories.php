<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            if (!Schema::hasColumn('categories', 'image')) {
                $table->string('image')->nullable()->after('description');
            }
        });

        Schema::table('sous_categories', function (Blueprint $table) {
            if (!Schema::hasColumn('sous_categories', 'image')) {
                $table->string('image')->nullable()->after('description');
            }
        });
    }

    public function down(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            if (Schema::hasColumn('categories', 'image')) {
                $table->dropColumn('image');
            }
        });

        Schema::table('sous_categories', function (Blueprint $table) {
            if (Schema::hasColumn('sous_categories', 'image')) {
                $table->dropColumn('image');
            }
        });
    }
};

