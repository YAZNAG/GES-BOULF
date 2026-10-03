<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Article;
use App\Models\Inventaire;
use App\Models\LigneInventaire;
use App\Models\MouvementStock;
use App\Models\Stock;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Inventaires : on ouvre une session, on compte les articles (scan ou recherche), on voit les écarts,
 * puis la validation aligne le stock sur les quantités comptées (mouvements « ajustement » tracés).
 * Les articles non comptés ne sont pas modifiés.
 */
class InventaireController extends Controller
{
    public function index(Request $request)
    {
        $q = Inventaire::query()->with(['famille:id,nom_fr', 'categorie:id,nom,name_fr', 'utilisateur:id,nom'])
            ->withCount('lignes')
            ->latest('id');
        if ($request->filled('statut')) {
            $q->where('statut', $request->query('statut'));
        }

        return response()->json($q->paginate(max(1, min(100, (int) $request->query('per_page', 30)))));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'libelle' => ['nullable', 'string', 'max:150'],
            'famille_id' => ['nullable', 'integer', 'exists:familles,id'],
            'categorie_id' => ['nullable', 'integer', 'exists:categories,id'],
            'note' => ['nullable', 'string', 'max:2000'],
        ]);
        $inv = DB::transaction(function () use ($data, $request) {
            $year = now()->format('Y');
            $last = Inventaire::query()->where('numero', 'like', "INV-{$year}-%")->lockForUpdate()->max('numero');
            $numero = sprintf('INV-%s-%04d', $year, $last ? ((int) substr($last, -4)) + 1 : 1);

            return Inventaire::query()->create([
                'numero' => $numero,
                'libelle' => $data['libelle'] ?? 'Inventaire du '.now()->format('d/m/Y'),
                'statut' => 'en_cours',
                'famille_id' => $data['famille_id'] ?? null,
                'categorie_id' => $data['categorie_id'] ?? null,
                'note' => $data['note'] ?? null,
                'utilisateur_id' => $request->user()?->id,
            ]);
        });

        return response()->json($inv, 201);
    }

    /** Détail : lignes (recherche q, filtre ecart=1) et synthèse des écarts. */
    public function show(Request $request, int $id)
    {
        $inv = Inventaire::query()->with(['famille:id,nom_fr', 'categorie:id,nom,name_fr', 'utilisateur:id,nom'])->findOrFail($id);
        $lignes = $inv->lignes()->with('article:id,nom,name_fr,name_ar,code_article,unite,image')->latest('updated_at');
        if ($s = trim((string) $request->query('q', ''))) {
            $lignes->whereHas('article', fn ($a) => $a->where('nom', 'like', "%{$s}%")->orWhere('code_article', 'like', "%{$s}%"));
        }
        if ($request->boolean('ecart')) {
            $lignes->whereColumn('quantite_comptee', '!=', 'quantite_theorique');
        }
        $all = $inv->lignes()->get();

        return response()->json([
            'inventaire' => $inv,
            'lignes' => $lignes->limit(500)->get(),
            'resume' => [
                'comptes' => $all->count(),
                'avec_ecart' => $all->filter(fn ($l) => abs($l->ecart) > 0.0005)->count(),
                'manquants' => round($all->filter(fn ($l) => $l->ecart < 0)->sum('ecart'), 3),
                'excedents' => round($all->filter(fn ($l) => $l->ecart > 0)->sum('ecart'), 3),
                'ecart_valeur' => round($all->sum('ecart_valeur'), 2),
                'perimetre' => $this->perimetre($inv)->count(),
            ],
        ]);
    }

    /**
     * Comptage d'un article. mode=set : la quantité saisie remplace ; mode=add : elle s'ajoute
     * (pratique quand un même article est rangé à plusieurs endroits).
     */
    public function compter(Request $request, int $id)
    {
        $data = $request->validate([
            'article_id' => ['required', 'integer', 'exists:articles,id'],
            'quantite' => ['required', 'numeric', 'min:0'],
            'mode' => ['nullable', 'in:set,add'],
        ]);
        $inv = $this->ouvert($id);

        $ligne = DB::transaction(function () use ($inv, $data, $request) {
            $article = Article::query()->with(['stock', 'prix'])->findOrFail($data['article_id']);
            $ligne = LigneInventaire::query()->lockForUpdate()->firstOrNew(['inventaire_id' => $inv->id, 'article_id' => $article->id]);
            if (! $ligne->exists) {
                // Le stock théorique est figé au premier comptage de l'article.
                $ligne->quantite_theorique = (float) ($article->stock?->quantite ?? 0);
                $ligne->prix_achat = (float) ($article->prix?->prix_achat ?? 0);
                $ligne->quantite_comptee = 0;
            }
            $ligne->quantite_comptee = ($data['mode'] ?? 'set') === 'add'
                ? (float) $ligne->quantite_comptee + (float) $data['quantite']
                : (float) $data['quantite'];
            $ligne->utilisateur_id = $request->user()?->id;
            $ligne->save();

            return $ligne;
        });

        return response()->json($ligne->load('article:id,nom,name_fr,name_ar,code_article,unite,image'));
    }

    public function retirerLigne(int $id, int $ligne)
    {
        $inv = $this->ouvert($id);
        LigneInventaire::query()->where('inventaire_id', $inv->id)->whereKey($ligne)->delete();

        return response()->json(['deleted' => true]);
    }

    /** Validation : stock = quantité comptée pour chaque ligne, avec mouvement d'ajustement. */
    public function valider(Request $request, int $id)
    {
        $inv = $this->ouvert($id);
        $userId = $request->user()?->id;

        $resultat = DB::transaction(function () use ($inv, $userId) {
            $corrections = 0;
            foreach ($inv->lignes()->get() as $l) {
                $stock = Stock::query()->lockForUpdate()->firstOrCreate(['article_id' => $l->article_id], ['quantite' => 0, 'seuil_min' => 0]);
                // Écart calculé sur le stock actuel : les ventes faites pendant le comptage restent prises en compte.
                $ecart = round((float) $l->quantite_comptee - (float) $l->quantite_theorique, 3);
                if (abs($ecart) < 0.0005) {
                    continue;
                }
                $stock->quantite = max(0, (float) $stock->quantite + $ecart);
                $stock->save();
                MouvementStock::query()->create([
                    'article_id' => $l->article_id,
                    'type_mouvement' => $ecart > 0 ? 'entree' : 'sortie',
                    'motif' => 'ajustement',
                    'quantite' => abs($ecart),
                    'reference_id' => $inv->id,
                    'reference_type' => 'inventaire',
                    'utilisateur_id' => $userId,
                    'note' => "{$inv->numero} : compté {$l->quantite_comptee}, théorique {$l->quantite_theorique}",
                ]);
                $corrections++;
            }
            $inv->update(['statut' => 'valide', 'valide_le' => now(), 'valide_par' => $userId]);

            return $corrections;
        });

        return response()->json(['inventaire' => $inv->fresh(), 'corrections' => $resultat]);
    }

    public function annuler(int $id)
    {
        $inv = $this->ouvert($id);
        $inv->update(['statut' => 'annule']);

        return response()->json($inv);
    }

    private function ouvert(int $id): Inventaire
    {
        $inv = Inventaire::query()->findOrFail($id);
        if ($inv->statut !== 'en_cours') {
            throw ValidationException::withMessages(['statut' => 'Cet inventaire est clôturé.']);
        }

        return $inv;
    }

    /** Articles concernés par l'inventaire (périmètre famille / catégorie). */
    private function perimetre(Inventaire $inv)
    {
        $q = Article::query()->where('actif', true);
        if ($inv->categorie_id) {
            $q->whereHas('sousCategorie', fn ($s) => $s->where('categorie_id', $inv->categorie_id));
        } elseif ($inv->famille_id) {
            $q->whereHas('sousCategorie.categorie', fn ($c) => $c->where('famille_id', $inv->famille_id));
        }

        return $q;
    }
}
