<?php

namespace App\Console\Commands;

use App\Models\Article;
use App\Models\Category;
use App\Models\Famille;
use App\Models\Marque;
use App\Models\SousCategorie;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Importe un catalogue (format catalogue_maroc.json, issu d'Open Food Facts) :
 * Familles → Catégories → Sous-catégories → Articles, avec images, marques et codes EAN13.
 *
 *   php artisan catalogue:import /chemin/catalogue_maroc.json /chemin/images --reset
 *
 * --reset vide d'abord le catalogue ET les données qui en dépendent (ventes, commandes, factures,
 * paiements, retours, mouvements de stock, packs, promotions). Utilisateurs, rôles, clients,
 * fournisseurs, unités et modes de paiement sont conservés.
 */
class ImportCatalogue extends Command
{
    protected $signature = 'catalogue:import {json : Fichier catalogue_maroc.json} {images : Dossier racine des images}
                            {--reset : Vider le catalogue et les données qui en dépendent avant l\'import}
                            {--actif : Importer les articles actifs (par défaut : inactifs, prix à 0 à compléter)}';

    protected $description = 'Importe le catalogue Open Food Facts (familles, catégories, sous-catégories, articles et images)';

    /** Familles (univers) et catégories du catalogue qu'elles regroupent. */
    private const FAMILLES = [
        ['Alimentation', 'المواد الغذائية', ['Boissons', 'Produits laitiers & œufs', 'Petit déjeuner', 'Épicerie',
            'Riz, pâtes & semoule', 'Biscuits & snacking', 'Chocolaterie & pâtisserie', 'Surgelés']],
        ['Hygiène & beauté', 'النظافة والجمال', ['Hygiène, beauté & soins']],
        ['Bébé', 'الطفل', ['La maison de bébé']],
        ['Entretien de la maison', 'تنظيف المنزل', ['Entretien']],
    ];

    /** Tables vidées par --reset (ordre : dépendances d'abord). */
    private const RESET_TABLES = [
        'paiements', 'factures', 'retours', 'lignes_commande_vente', 'commandes_vente', 'ventes',
        'lignes_commande_achat', 'commandes_achat', 'mouvements_stock', 'sorties', 'pack_items', 'packs',
        'promotions', 'prix_articles', 'stock', 'articles', 'sub_categories', 'sous_categories', 'categories',
        'familles', 'marques',
    ];

    public function handle(): int
    {
        $json = $this->argument('json');
        $imagesRoot = rtrim($this->argument('images'), '/\\');
        if (! is_file($json) || ! is_dir($imagesRoot)) {
            $this->error('Fichier JSON ou dossier d\'images introuvable.');

            return self::FAILURE;
        }
        $data = json_decode(file_get_contents($json), true, 512, JSON_THROW_ON_ERROR);

        if ($this->option('reset')) {
            $this->resetCatalogue();
        }

        $disk = Storage::disk('public');
        $store = function (?string $relative, string $folder, string $name) use ($disk, $imagesRoot): ?string {
            if (! $relative) {
                return null;
            }
            $source = $imagesRoot.'/'.preg_replace('#^images/#', '', $relative);
            if (! is_file($source) || filesize($source) < 500) {
                return null;
            }
            $path = "catalogue/{$folder}/{$name}.jpg";
            $disk->put($path, file_get_contents($source));

            return Storage::url($path);
        };

        $byCategory = collect($data['categories'])->keyBy(fn ($c) => $c['categorie']['nom_fr']);
        $marques = Marque::query()->pluck('id', 'nom')->all();
        $actif = (bool) $this->option('actif');
        $created = $skipped = 0;

        foreach (self::FAMILLES as [$familleFr, $familleAr, $catNames]) {
            $cats = collect($catNames)->filter(fn ($n) => $byCategory->has($n))->values();
            if ($cats->isEmpty()) {
                continue;
            }
            $famille = Famille::query()->firstOrCreate(['nom_fr' => $familleFr], ['nom_ar' => $familleAr]);
            if (! $famille->image) {
                $famille->update(['image' => $store($this->representative($byCategory[$cats[0]]), 'familles', Str::slug($familleFr))]);
            }

            foreach ($cats as $catName) {
                $c = $byCategory[$catName];
                $category = Category::query()->firstOrCreate(
                    ['nom' => $catName, 'famille_id' => $famille->id],
                    ['name_fr' => $catName, 'name_ar' => $c['categorie']['nom_ar'] ?? null]
                );
                if (! $category->image) {
                    $category->update(['image' => $store($this->representative($c), 'categories', Str::slug($catName))]);
                }

                foreach ($c['sous_categories'] as $s) {
                    $sc = $s['sous_categorie'];
                    $sous = SousCategorie::query()->firstOrCreate(
                        ['nom' => $sc['nom_fr'], 'categorie_id' => $category->id],
                        ['name_fr' => $sc['nom_fr'], 'name_ar' => $sc['nom_ar'] ?? null]
                    );
                    if (! $sous->image) {
                        $sous->update(['image' => $store($this->representative(['sous_categories' => [$s]]), 'sous-categories', Str::slug($catName.'-'.$sc['nom_fr']))]);
                    }

                    foreach ($s['produits'] as $p) {
                        $code = $p['ean13'];
                        if (Article::query()->where('code_article', $code)->exists()) {
                            $skipped++;

                            continue;
                        }
                        $marqueId = null;
                        if (! empty($p['marque'])) {
                            $nom = Str::limit(trim($p['marque']), 100, '');
                            $marqueId = $marques[$nom] ??= Marque::query()->create(['nom' => $nom])->id;
                        }
                        DB::transaction(function () use ($p, $code, $sous, $marqueId, $actif, $store, &$created) {
                            $article = Article::query()->create([
                                'sous_categorie_id' => $sous->id,
                                'marque_id' => $marqueId,
                                'code_article' => $code,
                                'nom' => Str::limit($p['nom_produit_fr'], 150, ''),
                                'name_fr' => Str::limit($p['nom_produit_fr'], 150, ''),
                                'name_ar' => $p['nom_produit_ar'] ? Str::limit($p['nom_produit_ar'], 150, '') : null,
                                'description' => $this->description($p),
                                'unite' => 'pièce',
                                'image' => $store($p['image_locale'] ?? null, 'articles', $code),
                                'actif' => $actif,
                            ]);
                            $article->prix()->create(['prix_achat' => 0, 'prix_vente' => 0, 'prix_gros' => 0]);
                            $article->stock()->create(['quantite' => 0, 'seuil_min' => 5]);
                            $created++;
                        });
                    }
                }
            }
            $this->info("Famille « {$familleFr} » importée.");
        }

        $this->info("Articles créés : {$created} ; déjà présents (code EAN) : {$skipped}.");

        return self::SUCCESS;
    }

    private function resetCatalogue(): void
    {
        DB::statement('SET FOREIGN_KEY_CHECKS=0');
        try {
            foreach (self::RESET_TABLES as $table) {
                if (Schema::hasTable($table)) {
                    DB::table($table)->truncate();
                }
            }
        } finally {
            DB::statement('SET FOREIGN_KEY_CHECKS=1');
        }
        Storage::disk('public')->deleteDirectory('catalogue');
        $this->warn('Catalogue et données dépendantes vidés.');
    }

    /** Image du produit le plus documenté de la catégorie (ou de la sous-catégorie). */
    private function representative(array $category): ?string
    {
        $best = null;
        $bestScore = -1;
        foreach ($category['sous_categories'] as $s) {
            foreach ($s['produits'] as $p) {
                if (empty($p['image_locale'])) {
                    continue;
                }
                $score = (int) ! empty($p['composition']) + (int) ! empty($p['marque']) + (count($s['produits']) > 10 ? 1 : 0);
                if ($score > $bestScore) {
                    [$best, $bestScore] = [$p['image_locale'], $score];
                }
            }
        }

        return $best;
    }

    private function description(array $p): string
    {
        $parts = array_filter([
            $p['description_fr'] ?? null,
            ! empty($p['poids_volume']) ? 'Contenance : '.$p['poids_volume'] : null,
            ! empty($p['composition']) ? 'Ingrédients : '.Str::limit($p['composition'], 1500) : null,
            ! empty($p['allergenes']) ? 'Allergènes : '.implode(', ', $p['allergenes']) : null,
            'Source : '.($p['source'] ?? 'Open Food Facts').' (ODbL) — '.($p['url_produit'] ?? ''),
        ]);

        return implode("\n", $parts);
    }
}
