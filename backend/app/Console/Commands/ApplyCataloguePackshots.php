<?php

namespace App\Console\Commands;

use App\Models\Article;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;

/**
 * Remplace les photos des articles par les photos « fond blanc » de images/_packshots/<code EAN>.jpg
 * (produites par packshot.py). Ne supprime aucune donnée.
 *
 *   php artisan catalogue:packshots /chemin/images
 */
class ApplyCataloguePackshots extends Command
{
    protected $signature = 'catalogue:packshots {images : Dossier racine des images (contenant _packshots/)}';

    protected $description = 'Applique les photos produits sur fond blanc aux articles (par code EAN)';

    public function handle(): int
    {
        $dir = rtrim($this->argument('images'), '/\\').'/_packshots';
        if (! is_dir($dir)) {
            $this->error("Introuvable : {$dir}");

            return self::FAILURE;
        }
        $disk = Storage::disk('public');
        $n = 0;
        foreach (glob($dir.'/*.jpg') as $file) {
            $code = basename($file, '.jpg');
            $article = Article::query()->where('code_article', $code)->first();
            if (! $article) {
                continue;
            }
            // Nom versionné : évite qu'un navigateur garde l'ancienne photo en cache.
            $path = 'catalogue/articles/'.$code.'-'.substr(md5_file($file), 0, 8).'.jpg';
            $disk->put($path, file_get_contents($file));
            $old = $article->image;
            $article->update(['image' => Storage::url($path)]);
            if ($old && str_starts_with($old, '/storage/catalogue/articles/') && $old !== Storage::url($path)) {
                $disk->delete(substr($old, strlen('/storage/')));
            }
            $n++;
        }
        $this->info("Photos remplacées : {$n}.");

        return self::SUCCESS;
    }
}
