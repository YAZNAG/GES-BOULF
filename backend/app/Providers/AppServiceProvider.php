<?php

namespace App\Providers;

use App\Models\Article;
use App\Models\Category;
use App\Models\Client;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Relation::morphMap([
            'article' => Article::class,
            'category' => Category::class,
            'client' => Client::class,
        ]);
    }
}
