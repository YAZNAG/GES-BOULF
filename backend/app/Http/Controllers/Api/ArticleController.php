<?php

namespace App\Http\Controllers\Api;

use App\Models\Article;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class ArticleController extends CrudController
{
    protected string $modelClass = Article::class;

    protected array $with = ['sousCategorie', 'marque', 'prix', 'stock'];

    protected array $storeRules = [
        'sous_categorie_id' => ['required', 'integer', 'exists:sous_categories,id'],
        'marque_id' => ['nullable', 'integer', 'exists:marques,id'],
        'code_article' => ['required', 'string', 'max:50', 'unique:articles,code_article'],
        'nom' => ['nullable', 'string', 'max:150'],
        'name_ar' => ['nullable', 'string', 'max:150'],
        'name_fr' => ['nullable', 'string', 'max:150'],
        'description' => ['nullable', 'string'],
        'unite' => ['nullable', 'string', 'max:20'],
        'image' => ['required','image'],
        'actif' => ['nullable', 'boolean'],
        'prix_achat' => ['nullable', 'numeric', 'min:0'],
        'prix_vente' => ['nullable', 'numeric', 'min:0'],
        'prix_gros' => ['nullable', 'numeric', 'min:0'],
        'stock_initial' => ['nullable', 'numeric'],
        'seuil_min' => ['nullable', 'numeric', 'min:0'],
    ];

    protected array $updateRules = [
        'sous_categorie_id' => ['sometimes', 'required', 'integer', 'exists:sous_categories,id'],
        'marque_id' => ['nullable', 'integer', 'exists:marques,id'],
        'code_article' => ['sometimes', 'required', 'string', 'max:50'],
        'nom' => ['sometimes', 'required', 'string', 'max:150'],
        'name_ar' => ['nullable', 'string', 'max:150'],
        'name_fr' => ['nullable', 'string', 'max:150'],
        'description' => ['nullable', 'string'],
        'unite' => ['nullable', 'string', 'max:20', 'exists:unites,nom'],
        'image' => ['nullable', 'image'],
        'actif' => ['nullable', 'boolean'],
    ];

    /**
     * Liste des articles avec recherche, filtres et pagination côté serveur.
     * Paramètres : q, famille_id, categorie_id, sous_categorie_id, marque_id,
     * statut (actif|inactif|a_tarifer|rupture), sort (nom|recent|prix_asc|prix_desc), per_page (≤ 5000), with_stats=1.
     */
    public function index(Request $request)
    {
        $query = Article::query()->with(['sousCategorie.categorie.famille', 'marque', 'prix', 'stock']);
        $this->applyFilters($query, $request);

        match ($request->query('sort', 'nom')) {
            'recent' => $query->orderByDesc('articles.id'),
            'prix_asc', 'prix_desc' => $query->leftJoin('prix_articles as pa', 'pa.article_id', '=', 'articles.id')
                ->select('articles.*')
                ->orderBy('pa.prix_vente', $request->query('sort') === 'prix_asc' ? 'asc' : 'desc'),
            default => $query->orderBy('articles.nom'),
        };

        $perPage = max(1, min(5000, (int) $request->query('per_page', 20)));
        $page = $query->paginate($perPage)->toArray();

        if ($request->boolean('with_stats')) {
            $page['stats'] = [
                'total' => Article::query()->count(),
                'actifs' => Article::query()->where('actif', true)->count(),
                'a_tarifer' => Article::query()->whereDoesntHave('prix', fn ($p) => $p->where('prix_vente', '>', 0))->count(),
                'rupture' => Article::query()->whereDoesntHave('stock', fn ($s) => $s->where('quantite', '>', 0))->count(),
                'marques' => \App\Models\Marque::query()->count(),
            ];
        }

        return response()->json($page);
    }

    /**
     * Recherche exacte par code-barres (EAN) ou code article — caisse et réceptions.
     * GET /api/articles/lookup?code=6111…
     */
    public function lookup(Request $request)
    {
        $code = trim((string) $request->query('code', ''));
        abort_if($code === '', 422, 'Code manquant.');
        $article = Article::query()->with(['sousCategorie', 'marque', 'prix', 'stock'])
            ->where('code_article', $code)
            ->first();
        // Lecteurs qui ajoutent ou retirent le zéro initial (UPC-A ↔ EAN-13).
        $article ??= Article::query()->with(['sousCategorie', 'marque', 'prix', 'stock'])
            ->whereIn('code_article', array_unique([ltrim($code, '0'), '0'.$code]))
            ->first();

        return $article ? response()->json($article) : response()->json(['message' => "Aucun article pour le code {$code}."], 404);
    }

    /**
     * Fiche automatique pour un code-barres inconnu (bases ouvertes + assistant IA facultatif).
     * GET /api/articles/fiche?code=…  → {deja_existant: article|null, fiche: {...}}
     */
    public function fiche(Request $request, \App\Services\ProduitEnrichService $enrich)
    {
        $code = trim((string) $request->query('code', ''));
        abort_unless(preg_match('/^\d{6,14}$/', $code), 422, 'Code-barres invalide.');
        $existant = Article::query()->with(['prix', 'stock', 'marque'])->where('code_article', $code)->first();

        return response()->json([
            'deja_existant' => $existant,
            'fiche' => $existant ? null : $enrich->enrich($code),
        ]);
    }

    /**
     * Ajout rapide d'un article scanné : la photo est téléchargée par le serveur depuis image_url.
     * Seul le prix de vente est indispensable ; l'article est créé actif, avec un stock à 0.
     */
    public function rapide(Request $request)
    {
        $data = $request->validate([
            'code_article' => ['nullable', 'string', 'max:50', 'unique:articles,code_article'],
            'name_fr' => ['required', 'string', 'max:150'],
            'name_ar' => ['nullable', 'string', 'max:150'],
            'marque' => ['nullable', 'string', 'max:100'],
            'sous_categorie_id' => ['required', 'integer', 'exists:sous_categories,id'],
            'image_url' => ['nullable', 'url', 'max:500'],
            'image' => ['nullable', 'image', 'max:10240'],
            'prix_vente' => ['required', 'numeric', 'gt:0'],
            'prix_achat' => ['nullable', 'numeric', 'min:0'],
            'unite' => ['nullable', 'string', 'max:20', 'exists:unites,nom'],
        ]);

        // Produit sans code-barres (vrac, produit maison…) : code interne EAN-13 imprimable en étiquette.
        $data['code_article'] = trim((string) ($data['code_article'] ?? '')) ?: $this->codeInterne();

        $article = \Illuminate\Support\Facades\DB::transaction(function () use ($data) {
            $marqueId = null;
            if (! empty($data['marque'])) {
                $marqueId = \App\Models\Marque::query()->firstOrCreate(['nom' => trim($data['marque'])])->id;
            }
            $article = Article::query()->create([
                'sous_categorie_id' => $data['sous_categorie_id'],
                'marque_id' => $marqueId,
                'code_article' => $data['code_article'],
                'nom' => $data['name_fr'],
                'name_fr' => $data['name_fr'],
                'name_ar' => $data['name_ar'] ?? null,
                'unite' => $data['unite'] ?? 'pièce',
                'actif' => true,
            ]);
            $article->prix()->create([
                'prix_achat' => $data['prix_achat'] ?? 0,
                'prix_vente' => $data['prix_vente'],
                'prix_gros' => $data['prix_vente'],
            ]);
            $article->stock()->create(['quantite' => 0, 'seuil_min' => 5]);

            return $article;
        });

        // Photo prise avec le téléphone…
        if ($request->hasFile('image')) {
            $path = $request->file('image')->store('articles/'.$article->id, 'public');
            $article->update(['image' => Storage::url($path)]);
        }
        // … ou téléchargée depuis les bases ouvertes connues (pas d'URL arbitraire).
        elseif (! empty($data['image_url']) && preg_match('#^https://images\.open(food|beauty|products)facts\.org/#', $data['image_url'])) {
            try {
                $img = \Illuminate\Support\Facades\Http::timeout(15)->get($data['image_url']);
                if ($img->ok() && str_starts_with((string) $img->header('Content-Type'), 'image/') && strlen($img->body()) < 5_000_000) {
                    $path = "articles/{$article->id}/{$article->code_article}.jpg";
                    Storage::disk('public')->put($path, $img->body());
                    $article->update(['image' => Storage::url($path)]);
                }
            } catch (\Throwable $e) {
                \Illuminate\Support\Facades\Log::info("Photo non récupérée pour {$article->code_article} : {$e->getMessage()}");
            }
        }

        $this->logAction('create', 'articles', (int) $article->id, ['source' => 'ajout rapide', 'code' => $article->code_article]);

        return response()->json($article->load($this->with), 201);
    }

    /**
     * Code interne au format EAN-13 avec préfixe 20 (réservé à l'usage interne des magasins) :
     * 20 + 10 chiffres + clé de contrôle. Unique et scannable comme un vrai code-barres.
     */
    private function codeInterne(): string
    {
        $n = (int) Article::query()->max('id') + 1;
        do {
            $base = '20'.str_pad((string) $n, 10, '0', STR_PAD_LEFT);
            $sum = 0;
            foreach (str_split($base) as $i => $d) {
                $sum += (int) $d * ($i % 2 ? 3 : 1);
            }
            $code = $base.((10 - $sum % 10) % 10);
            $n++;
        } while (Article::query()->where('code_article', $code)->exists());

        return $code;
    }

    private function applyFilters($query, Request $request): void
    {
        if ($q = trim((string) $request->query('q', ''))) {
            $query->where(function ($w) use ($q) {
                $w->where('articles.nom', 'like', "%{$q}%")
                    ->orWhere('articles.name_fr', 'like', "%{$q}%")
                    ->orWhere('articles.name_ar', 'like', "%{$q}%")
                    ->orWhere('articles.code_article', 'like', "%{$q}%")
                    ->orWhereHas('marque', fn ($m) => $m->where('nom', 'like', "%{$q}%"));
            });
        }
        if ($request->filled('sous_categorie_id')) {
            $query->where('articles.sous_categorie_id', $request->query('sous_categorie_id'));
        }
        if ($request->filled('categorie_id')) {
            $query->whereHas('sousCategorie', fn ($s) => $s->where('categorie_id', $request->query('categorie_id')));
        }
        if ($request->filled('famille_id')) {
            $query->whereHas('sousCategorie.categorie', fn ($c) => $c->where('famille_id', $request->query('famille_id')));
        }
        if ($request->filled('marque_id')) {
            $query->where('articles.marque_id', $request->query('marque_id'));
        }
        match ($request->query('statut')) {
            'actif' => $query->where('articles.actif', true),
            'inactif' => $query->where('articles.actif', false),
            'a_tarifer' => $query->whereDoesntHave('prix', fn ($p) => $p->where('prix_vente', '>', 0)),
            'rupture' => $query->whereDoesntHave('stock', fn ($s) => $s->where('quantite', '>', 0)),
            default => null,
        };
    }

    public function store(Request $request)
    {
        $data = $request->validate($this->storeRules);

        /** @var Article $model */
        $model = new $this->modelClass();

        try {
            return \Illuminate\Support\Facades\DB::transaction(function () use ($request, $data, $model) {
                $imageFile = $request->file('image');
                unset($data['image']);

                $data['nom'] = (!empty($data['name_fr']) ? $data['name_fr'] : (!empty($data['name_ar']) ? $data['name_ar'] : 'Sans nom'));
                $model->fill($data);
                $model->save();

                $path = $imageFile->store('articles/' . $model->id, 'public');
                $model->image = Storage::url($path);
                $model->save();

                if ($request->has('prix_vente')) {
                    $model->prix()->create([
                        'prix_achat' => $request->input('prix_achat', 0),
                        'prix_vente' => $request->input('prix_vente', 0),
                        'prix_gros' => $request->input('prix_gros', $request->input('prix_vente', 0)),
                    ]);
                }

                if ($request->has('stock_initial')) {
                    $model->stock()->create([
                        'quantite' => $request->input('stock_initial', 0),
                        'seuil_min' => $request->input('seuil_min', 5),
                    ]);
                }

                $this->logAction('create', $model->getTable(), (int) $model->getKey(), $data);
                $model->load($this->with);
                return response()->json($model, 201);
            });
        } catch (QueryException $e) {
            if ($this->isFkConstraint($e)) {
                return response()->json([
                    'message' => $this->fkMessage($e, $model),
                    'code' => 'FK_CONSTRAINT',
                    'constraint' => $this->extractConstraintName($e),
                ], 409);
            }
            throw $e;
        }
    }

    public function update(Request $request, string $id)
    {
        /** @var Article $model */
        $model = ($this->modelClass)::query()->findOrFail($id);

        $rules = $this->updateRules;
        $rules['code_article'] = [
            'sometimes',
            'required',
            'string',
            'max:50',
            Rule::unique('articles', 'code_article')->ignore($model->id),
        ];

        $data = $request->validate($rules);

        try {
            if ($request->hasFile('image')) {
                $this->deletePublicFileIfAny($model->image);
                $path = $request->file('image')->store('articles/' . $model->id, 'public');
                $data['image'] = Storage::url($path);
            } else {
                unset($data['image']);
            }

            if (!empty($data['name_fr']) || !empty($data['name_ar'])) {
                $data['nom'] = !empty($data['name_fr']) ? $data['name_fr'] : $data['name_ar'];
            }
            $model->fill($data);
            $model->save();
        } catch (QueryException $e) {
            if ($this->isFkConstraint($e)) {
                return response()->json([
                    'message' => $this->fkMessage($e, $model),
                    'code' => 'FK_CONSTRAINT',
                    'constraint' => $this->extractConstraintName($e),
                ], 409);
            }
            throw $e;
        }

        $this->logAction('update', $model->getTable(), (int) $model->getKey(), $data);

        $model->load($this->with);
        return response()->json($model);
    }

    private function deletePublicFileIfAny(?string $url): void
    {
        if (!$url) return;
        if (!str_starts_with($url, '/storage/')) return;
        $path = ltrim(substr($url, strlen('/storage/')), '/');
        if ($path) {
            Storage::disk('public')->delete($path);
        }
    }

    /** Où l'article est utilisé : la suppression n'est permise que s'il ne l'est nulle part. */
    public function usage(string $id)
    {
        $article = Article::query()->findOrFail($id);
        $usages = \App\Support\Utilisation::de('articles', (int) $article->id);

        return response()->json(['utilisations' => $usages, 'supprimable' => empty($usages), 'actif' => (bool) $article->actif]);
    }

    public function destroy(string $id)
    {
        $article = Article::query()->findOrFail($id);
        $usages = \App\Support\Utilisation::de('articles', (int) $article->id);
        if ($usages) {
            return \App\Support\Utilisation::refus('cet article', $usages);
        }
        $image = $article->image;
        $article->delete(); // prix et stock suivent (cascade)
        if ($image && str_starts_with($image, '/storage/')) {
            Storage::disk('public')->delete(substr($image, strlen('/storage/')));
        }
        $this->logAction('delete', 'articles', (int) $id);

        return response()->json(['deleted' => true]);
    }
}
