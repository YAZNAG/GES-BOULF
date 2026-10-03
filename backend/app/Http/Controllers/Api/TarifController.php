<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Article;
use App\Models\PrixArticle;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Tarifs de vente : tableau des produits avec prix d'achat, de vente, de gros, promo et marge.
 */
class TarifController extends Controller
{
    /** Taux de marque en % : (vente - achat) / vente. */
    private const MARGE_SQL = 'CASE WHEN COALESCE(pa.prix_vente,0) > 0 THEN (COALESCE(pa.prix_vente,0) - COALESCE(pa.prix_achat,0)) / pa.prix_vente * 100 ELSE NULL END';

    /**
     * Paramètres : q, famille_id, categorie_id, sous_categorie_id, marque_id,
     * statut (tarife|a_tarifer|promo|perte|marge_faible|sans_achat), actif (0|1),
     * sort (nom|vente_asc|vente_desc|achat_desc|marge_asc|marge_desc|maj), per_page (≤ 500).
     */
    public function index(Request $request)
    {
        $query = $this->base($request)
            ->with(['sousCategorie:id,nom,name_fr,categorie_id', 'sousCategorie.categorie:id,nom,name_fr,famille_id', 'marque:id,nom', 'stock:id,article_id,quantite'])
            ->select('articles.id', 'articles.nom', 'articles.name_fr', 'articles.name_ar', 'articles.code_article', 'articles.unite',
                'articles.image', 'articles.actif', 'articles.sous_categorie_id', 'articles.marque_id',
                'pa.id as prix_id', DB::raw('COALESCE(pa.prix_achat,0) as prix_achat'), DB::raw('COALESCE(pa.prix_vente,0) as prix_vente'),
                'pa.prix_gros', 'pa.prix_promo', 'pa.updated_at as prix_maj', DB::raw(self::MARGE_SQL.' as marge'));

        match ($request->query('sort', 'nom')) {
            'vente_asc' => $query->orderBy('prix_vente'),
            'vente_desc' => $query->orderByDesc('prix_vente'),
            'achat_desc' => $query->orderByDesc('prix_achat'),
            'marge_asc' => $query->orderByRaw('marge IS NULL, marge asc'),
            'marge_desc' => $query->orderByRaw('marge IS NULL, marge desc'),
            'maj' => $query->orderByDesc('pa.updated_at'),
            default => $query->orderBy('articles.nom'),
        };

        $page = $query->paginate(max(1, min(500, (int) $request->query('per_page', 50))))->toArray();

        $all = Article::query()->leftJoin('prix_articles as pa', 'pa.article_id', '=', 'articles.id');
        $page['stats'] = [
            'total' => (clone $all)->count(),
            'tarifes' => (clone $all)->where('pa.prix_vente', '>', 0)->count(),
            'a_tarifer' => (clone $all)->where(fn ($w) => $w->whereNull('pa.prix_vente')->orWhere('pa.prix_vente', '<=', 0))->count(),
            'promo' => (clone $all)->where('pa.prix_promo', '>', 0)->count(),
            'perte' => (clone $all)->where('pa.prix_vente', '>', 0)->whereColumn('pa.prix_vente', '<', 'pa.prix_achat')->count(),
            'marge_moyenne' => round((float) (clone $all)->where('pa.prix_vente', '>', 0)->where('pa.prix_achat', '>', 0)
                ->avg(DB::raw('(pa.prix_vente - pa.prix_achat) / pa.prix_vente * 100')), 1),
        ];

        return response()->json($page);
    }

    /** Export CSV-ready (mêmes filtres, sans pagination). */
    public function export(Request $request)
    {
        $rows = $this->base($request)
            ->leftJoin('sous_categories as sc', 'sc.id', '=', 'articles.sous_categorie_id')
            ->leftJoin('categories as c', 'c.id', '=', 'sc.categorie_id')
            ->leftJoin('marques as m', 'm.id', '=', 'articles.marque_id')
            ->orderBy('articles.nom')
            ->limit(20000)
            ->get(['articles.code_article', 'articles.nom', 'articles.name_ar', 'm.nom as marque', 'c.nom as categorie', 'sc.nom as sous_categorie',
                'articles.unite', 'pa.prix_achat', 'pa.prix_vente', 'pa.prix_gros', 'pa.prix_promo', DB::raw(self::MARGE_SQL.' as marge'), 'articles.actif']);

        return response()->json($rows);
    }

    /** Mise à jour des prix d'un article (création de la ligne de prix si besoin). */
    public function update(Request $request, int $articleId)
    {
        $data = $request->validate([
            'prix_achat' => ['nullable', 'numeric', 'min:0'],
            'prix_vente' => ['nullable', 'numeric', 'min:0'],
            'prix_gros' => ['nullable', 'numeric', 'min:0'],
            'prix_promo' => ['nullable', 'numeric', 'min:0'],
            'actif' => ['nullable', 'boolean'],
        ]);
        $article = Article::query()->findOrFail($articleId);
        $prix = PrixArticle::query()->firstOrNew(['article_id' => $article->id]);
        foreach (['prix_achat', 'prix_vente', 'prix_gros', 'prix_promo'] as $k) {
            if ($request->exists($k)) {
                $prix->{$k} = $data[$k] === null || $data[$k] === '' ? ($k === 'prix_achat' || $k === 'prix_vente' ? 0 : null) : $data[$k];
            }
        }
        $prix->prix_achat ??= 0;
        $prix->prix_vente ??= 0;
        $prix->save();

        if (array_key_exists('actif', $data) && $data['actif'] !== null) {
            $article->update(['actif' => $data['actif']]);
        } elseif ((float) $prix->prix_vente > 0 && ! $article->actif && $request->exists('prix_vente')) {
            // Un produit qu'on vient de tarifer devient vendable.
            $article->update(['actif' => true]);
        }

        return response()->json(['prix' => $prix->fresh(), 'actif' => $article->fresh()->actif]);
    }

    /**
     * Action groupée sur une sélection :
     *  - marge : prix de vente = achat / (1 - marge%)        (valeur = marge en %)
     *  - coef : prix de vente = achat × coefficient          (valeur = 1.25…)
     *  - hausse : prix de vente × (1 + valeur%)               (valeur peut être négative)
     *  - promo : prix promo = vente × (1 - valeur%) ; valeur 0 = retirer la promo
     *  - activer / desactiver
     * arrondi : 0.05, 0.10, 0.50, 1 (arrondi supérieur) — facultatif.
     */
    public function bulk(Request $request)
    {
        $data = $request->validate([
            'article_ids' => ['required', 'array', 'min:1', 'max:5000'],
            'article_ids.*' => ['integer'],
            'action' => ['required', 'in:marge,coef,hausse,promo,activer,desactiver'],
            'valeur' => ['nullable', 'numeric'],
            'arrondi' => ['nullable', 'numeric', 'in:0.01,0.05,0.1,0.5,1'],
        ]);
        $v = (float) ($data['valeur'] ?? 0);
        $round = function (float $p) use ($data) {
            $step = (float) ($data['arrondi'] ?? 0.01);

            return round(ceil(round($p / $step, 6)) * $step, 2);
        };
        $n = 0;
        $ignores = 0;

        DB::transaction(function () use ($data, $v, $round, &$n, &$ignores) {
            if (in_array($data['action'], ['activer', 'desactiver'], true)) {
                $n = Article::query()->whereIn('id', $data['article_ids'])->update(['actif' => $data['action'] === 'activer']);

                return;
            }
            foreach (array_chunk($data['article_ids'], 500) as $ids) {
                foreach (Article::query()->whereIn('id', $ids)->with('prix')->get() as $a) {
                    $prix = $a->prix ?? new PrixArticle(['article_id' => $a->id, 'prix_achat' => 0, 'prix_vente' => 0]);
                    $achat = (float) $prix->prix_achat;
                    $vente = (float) $prix->prix_vente;
                    switch ($data['action']) {
                        case 'marge':
                            if ($achat <= 0 || $v >= 100) { $ignores++; continue 2; }
                            $prix->prix_vente = $round($achat / (1 - $v / 100));
                            break;
                        case 'coef':
                            if ($achat <= 0 || $v <= 0) { $ignores++; continue 2; }
                            $prix->prix_vente = $round($achat * $v);
                            break;
                        case 'hausse':
                            if ($vente <= 0) { $ignores++; continue 2; }
                            $prix->prix_vente = $round($vente * (1 + $v / 100));
                            break;
                        case 'promo':
                            if ($vente <= 0) { $ignores++; continue 2; }
                            $prix->prix_promo = $v > 0 ? $round($vente * (1 - $v / 100)) : null;
                            break;
                    }
                    $prix->save();
                    if (in_array($data['action'], ['marge', 'coef'], true) && (float) $prix->prix_vente > 0 && ! $a->actif) {
                        $a->update(['actif' => true]);
                    }
                    $n++;
                }
            }
        });

        return response()->json(['modifies' => $n, 'ignores' => $ignores]);
    }

    private function base(Request $request)
    {
        $query = Article::query()->leftJoin('prix_articles as pa', 'pa.article_id', '=', 'articles.id');

        if ($q = trim((string) $request->query('q', ''))) {
            $query->where(fn ($w) => $w->where('articles.nom', 'like', "%{$q}%")->orWhere('articles.name_ar', 'like', "%{$q}%")
                ->orWhere('articles.code_article', 'like', "%{$q}%")
                ->orWhereHas('marque', fn ($m) => $m->where('nom', 'like', "%{$q}%")));
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
        if ($request->filled('actif')) {
            $query->where('articles.actif', $request->boolean('actif'));
        }
        match ($request->query('statut')) {
            'tarife' => $query->where('pa.prix_vente', '>', 0),
            'a_tarifer' => $query->where(fn ($w) => $w->whereNull('pa.prix_vente')->orWhere('pa.prix_vente', '<=', 0)),
            'promo' => $query->where('pa.prix_promo', '>', 0),
            'perte' => $query->where('pa.prix_vente', '>', 0)->whereColumn('pa.prix_vente', '<', 'pa.prix_achat'),
            'marge_faible' => $query->where('pa.prix_vente', '>', 0)->where('pa.prix_achat', '>', 0)
                ->whereRaw('(pa.prix_vente - pa.prix_achat) / pa.prix_vente * 100 < 10'),
            'sans_achat' => $query->where(fn ($w) => $w->whereNull('pa.prix_achat')->orWhere('pa.prix_achat', '<=', 0)),
            default => null,
        };

        return $query;
    }
}
