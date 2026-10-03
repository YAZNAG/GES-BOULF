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
}
