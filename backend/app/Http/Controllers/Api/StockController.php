<?php

namespace App\Http\Controllers\Api;

use App\Models\Stock;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class StockController extends CrudController
{
    protected string $modelClass = Stock::class;

    protected array $with = ['article'];

    protected array $storeRules = [
        'article_id' => ['required', 'integer', 'exists:articles,id', 'unique:stock,article_id'],
        'quantite' => ['nullable', 'numeric'],
        'seuil_min' => ['nullable', 'numeric', 'min:0'],
    ];

    protected array $updateRules = [
        'quantite' => ['sometimes', 'required', 'numeric'],
        'seuil_min' => ['nullable', 'numeric', 'min:0'],
    ];

    /**
     * Articles en stock.
     * Paramètres : q, statut (en_stock|sous_seuil|rupture), famille_id, categorie_id,
     * sort (nom|quantite_asc|quantite_desc|valeur), per_page, with_stats=1.
     */
    public function index(Request $request)
    {
        $query = Stock::query()
            ->join('articles', 'articles.id', '=', 'stock.article_id')
            ->leftJoin('prix_articles as pa', 'pa.article_id', '=', 'stock.article_id')
            ->select('stock.*', DB::raw('COALESCE(pa.prix_achat, 0) as prix_achat'), DB::raw('COALESCE(pa.prix_vente, 0) as prix_vente'),
                DB::raw('stock.quantite * COALESCE(pa.prix_achat, 0) as valeur_achat'))
            ->with(['article:id,nom,name_fr,name_ar,code_article,unite,image,actif,sous_categorie_id,marque_id', 'article.sousCategorie:id,nom,name_fr,categorie_id', 'article.marque:id,nom']);

        if ($q = trim((string) $request->query('q', ''))) {
            $query->where(fn ($w) => $w->where('articles.nom', 'like', "%{$q}%")->orWhere('articles.name_ar', 'like', "%{$q}%")
                ->orWhere('articles.code_article', 'like', "%{$q}%"));
        }
        match ($request->query('statut')) {
            'en_stock' => $query->where('stock.quantite', '>', 0),
            'sous_seuil' => $query->where('stock.quantite', '>', 0)->whereColumn('stock.quantite', '<=', 'stock.seuil_min'),
            'rupture' => $query->where('stock.quantite', '<=', 0)->where('articles.actif', true),
            default => null,
        };
        if ($request->filled('categorie_id')) {
            $query->whereHas('article.sousCategorie', fn ($s) => $s->where('categorie_id', $request->query('categorie_id')));
        }
        if ($request->filled('famille_id')) {
            $query->whereHas('article.sousCategorie.categorie', fn ($c) => $c->where('famille_id', $request->query('famille_id')));
        }
        match ($request->query('sort', 'nom')) {
            'quantite_asc' => $query->orderBy('stock.quantite'),
            'quantite_desc' => $query->orderByDesc('stock.quantite'),
            'valeur' => $query->orderByDesc('valeur_achat'),
            default => $query->orderBy('articles.nom'),
        };

        $page = $query->paginate(max(1, min(1000, (int) $request->query('per_page', 30))))->toArray();

        if ($request->boolean('with_stats')) {
            $base = fn () => Stock::query()->join('articles', 'articles.id', '=', 'stock.article_id');
            $valeurs = Stock::query()->leftJoin('prix_articles as pa', 'pa.article_id', '=', 'stock.article_id')
                ->where('stock.quantite', '>', 0)
                ->selectRaw('SUM(stock.quantite * COALESCE(pa.prix_achat,0)) as achat, SUM(stock.quantite * COALESCE(pa.prix_vente,0)) as vente')
                ->first();
            $page['stats'] = [
                'en_stock' => $base()->where('stock.quantite', '>', 0)->count(),
                'sous_seuil' => $base()->where('stock.quantite', '>', 0)->whereColumn('stock.quantite', '<=', 'stock.seuil_min')->count(),
                'rupture' => $base()->where('stock.quantite', '<=', 0)->where('articles.actif', true)->count(),
                'valeur_achat' => round((float) ($valeurs->achat ?? 0), 2),
                'valeur_vente' => round((float) ($valeurs->vente ?? 0), 2),
            ];
        }

        return response()->json($page);
    }
}
