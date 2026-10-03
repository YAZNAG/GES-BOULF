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
     * Ajustement de stock en une seule opération (stock + mouvement tracé).
     * mode : inventaire (quantité comptée), plus, moins. Le seuil minimum peut être modifié en même temps.
     */
    public function ajuster(Request $request)
    {
        $data = $request->validate([
            'article_id' => ['required', 'integer', 'exists:articles,id'],
            'mode' => ['required', 'in:inventaire,plus,moins'],
            'quantite' => ['required', 'numeric', 'min:0'],
            'motif' => ['nullable', 'in:perte,don,retour,ajustement'],
            'note' => ['nullable', 'string', 'max:500'],
            'seuil_min' => ['nullable', 'numeric', 'min:0'],
        ]);

        $stock = DB::transaction(function () use ($data, $request) {
            $stock = Stock::query()->lockForUpdate()->firstOrCreate(['article_id' => $data['article_id']], ['quantite' => 0, 'seuil_min' => 0]);
            $avant = (float) $stock->quantite;
            $apres = match ($data['mode']) {
                'inventaire' => (float) $data['quantite'],
                'plus' => $avant + (float) $data['quantite'],
                'moins' => $avant - (float) $data['quantite'],
            };
            abort_if($apres < 0, 422, 'Stock insuffisant : la quantité deviendrait négative.');
            $ecart = round($apres - $avant, 3);

            $stock->quantite = $apres;
            if (array_key_exists('seuil_min', $data) && $data['seuil_min'] !== null) {
                $stock->seuil_min = $data['seuil_min'];
            }
            $stock->save();

            if ($ecart != 0) {
                \App\Models\MouvementStock::query()->create([
                    'article_id' => $data['article_id'],
                    'type_mouvement' => $ecart > 0 ? 'entree' : 'sortie',
                    'motif' => $data['motif'] ?? 'ajustement',
                    'quantite' => abs($ecart),
                    'reference_type' => $data['mode'] === 'inventaire' ? 'inventaire' : 'ajustement',
                    'utilisateur_id' => $request->user()?->id,
                    'note' => $data['note'] ?? ($data['mode'] === 'inventaire' ? "Inventaire : {$avant} → {$apres}" : null),
                ]);
            }

            return $stock;
        });

        return response()->json($stock);
    }

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
        if ($request->filled('sous_categorie_id')) {
            $query->where('articles.sous_categorie_id', $request->query('sous_categorie_id'));
        }
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
