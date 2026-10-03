<?php

namespace App\Console\Commands;

use App\Models\Category;
use App\Models\Famille;
use App\Models\SousCategorie;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Remplace les images des familles, catégories et sous-catégories par les visuels générés
 * (images/_covers/covers.json, produit par make_covers.py). Ne supprime aucune donnée.
 *
 *   php artisan catalogue:covers /chemin/images
 */
class ApplyCatalogueCovers extends Command
{
    protected $signature = 'catalogue:covers {images : Dossier racine des images (contenant _covers/covers.json)}';

    protected $description = 'Applique les visuels générés aux familles, catégories et sous-catégories';

    public function handle(): int
    {
        $root = rtrim($this->argument('images'), '/\\');
        $file = $root.'/_covers/covers.json';
        if (! is_file($file)) {
            $this->error("Introuvable : {$file}");

            return self::FAILURE;
        }
        $covers = json_decode(file_get_contents($file), true);
        $disk = Storage::disk('public');
        $put = function (string $relative, string $folder, string $name) use ($root, $disk): ?string {
            $source = $root.'/'.$relative;
            if (! is_file($source)) {
                return null;
            }
            $path = "catalogue/{$folder}/{$name}-".substr(md5_file($source), 0, 8).'.jpg';
            $disk->put($path, file_get_contents($source));

            return Storage::url($path);
        };
        $n = 0;

        foreach ($covers['familles'] ?? [] as $nom => $rel) {
            foreach (Famille::query()->where('nom_fr', $nom)->get() as $f) {
                $f->update(['image' => $put($rel, 'familles', Str::slug($nom)) ?? $f->image]);
                $n++;
            }
        }
        foreach ($covers['categories'] ?? [] as $nom => $rel) {
            foreach (Category::query()->where('nom', $nom)->get() as $c) {
                $c->update(['image' => $put($rel, 'categories', Str::slug($nom)) ?? $c->image]);
                $n++;
            }
        }
        foreach ($covers['sous_categories'] ?? [] as $key => $rel) {
            [$cat, $sous] = explode('|', $key, 2);
            $items = SousCategorie::query()->where('nom', $sous)->whereHas('categorie', fn ($q) => $q->where('nom', $cat))->get();
            foreach ($items as $s) {
                $s->update(['image' => $put($rel, 'sous-categories', Str::slug($cat.'-'.$sous)) ?? $s->image]);
                $n++;
            }
        }
        $this->info("Visuels appliqués : {$n}.");

        return self::SUCCESS;
    }
}
