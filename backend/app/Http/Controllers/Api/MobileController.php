<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Article;
use App\Models\Client;
use App\Models\Fournisseur;
use App\Models\LigneCommandeVente;
use App\Models\MouvementStock;
use App\Models\Stock;
use App\Models\Vente;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Points d'accès pensés pour l'application mobile (et réutilisables par le site) :
 * tableau de bord, ventes, crédit clients, mouvements de stock, version de l'application.
 */
class MobileController extends Controller
{
    /** Indicateurs du jour et du mois, alertes et dernières ventes. */
    public function dashboard()
    {
        $today = now()->startOfDay();
        $month = now()->startOfMonth();
        $ventes = fn ($from) => Vente::query()->where('date_vente', '>=', $from);

        $jours = collect(range(6, 0))->map(function ($i) {
            $d = now()->subDays($i)->startOfDay();
            $montant = (float) Vente::query()->whereBetween('date_vente', [$d, (clone $d)->endOfDay()])->sum('montant_total');

            return ['date' => $d->toDateString(), 'jour' => $d->locale('fr')->isoFormat('dd'), 'montant' => round($montant, 2)];
        });

        $top = LigneCommandeVente::query()
            ->join('ventes', 'ventes.commande_vente_id', '=', 'lignes_commande_vente.commande_vente_id')
            ->join('articles', 'articles.id', '=', 'lignes_commande_vente.article_id')
            ->where('ventes.date_vente', '>=', $month)
            ->groupBy('articles.id', 'articles.nom', 'articles.image')
            ->orderByDesc('qte')
            ->limit(5)
            ->get(['articles.id', 'articles.nom', 'articles.image', DB::raw('SUM(lignes_commande_vente.quantite) as qte'),
                DB::raw('SUM(lignes_commande_vente.quantite * lignes_commande_vente.prix_unitaire) as montant')]);

        return response()->json([
            'jour' => [
                'ventes' => $ventes($today)->count(),
                'montant' => round((float) $ventes($today)->sum('montant_total'), 2),
                'encaisse' => round((float) $ventes($today)->sum('montant_paye'), 2),
            ],
            'mois' => [
                'ventes' => $ventes($month)->count(),
                'montant' => round((float) $ventes($month)->sum('montant_total'), 2),
            ],
            'credit_clients' => round((float) Client::query()->where('solde', '>', 0)->sum('solde'), 2),
            'credit_fournisseurs' => round((float) Fournisseur::query()->where('solde', '>', 0)->sum('solde'), 2),
            'stock' => [
                'rupture' => Stock::query()->join('articles', 'articles.id', '=', 'stock.article_id')
                    ->where('articles.actif', true)->where('stock.quantite', '<=', 0)->count(),
                'sous_seuil' => Stock::query()->where('quantite', '>', 0)->whereColumn('quantite', '<=', 'seuil_min')->count(),
            ],
            'produits' => [
                'total' => Article::query()->count(),
                'actifs' => Article::query()->where('actif', true)->count(),
                'a_tarifer' => Article::query()->whereDoesntHave('prix', fn ($p) => $p->where('prix_vente', '>', 0))->count(),
            ],
            'sept_jours' => $jours,
            'top_produits' => $top,
            'dernieres_ventes' => Vente::query()->with('client:id,nom')->latest('date_vente')->limit(6)
                ->get(['id', 'client_id', 'montant_total', 'montant_paye', 'mode_paiement', 'date_vente']),
        ]);
    }

    /** Ventes : filtres du, au, client_id, mode (credit…), q (n° facture ou client). */
    public function ventes(Request $request)
    {
        $q = Vente::query()->with(['client:id,nom', 'facture:id,vente_id,numero_facture,statut', 'utilisateur:id,nom'])
            ->withCount('items')->latest('date_vente');
        if ($request->filled('du')) {
            $q->whereDate('date_vente', '>=', $request->query('du'));
        }
        if ($request->filled('au')) {
            $q->whereDate('date_vente', '<=', $request->query('au'));
        }
        if ($request->filled('client_id')) {
            $q->where('client_id', $request->query('client_id'));
        }
        if ($request->query('credit')) {
            $q->whereColumn('montant_paye', '<', 'montant_total');
        }
        if ($s = trim((string) $request->query('q', ''))) {
            $q->where(fn ($w) => $w->whereHas('client', fn ($c) => $c->where('nom', 'like', "%{$s}%"))
                ->orWhereHas('facture', fn ($f) => $f->where('numero_facture', 'like', "%{$s}%")));
        }
        $total = (clone $q)->reorder();
        $page = $q->paginate(max(1, min(100, (int) $request->query('per_page', 25))))->toArray();
        $page['resume'] = [
            'montant' => round((float) $total->sum('montant_total'), 2),
            'encaisse' => round((float) (clone $total)->sum('montant_paye'), 2),
        ];

        return response()->json($page);
    }

    public function vente(int $id)
    {
        return response()->json(Vente::query()
            ->with(['client', 'facture', 'utilisateur:id,nom', 'items.article:id,nom,name_fr,name_ar,code_article,image,unite'])
            ->findOrFail($id));
    }

    /** Clients avec crédit (solde), recherche et total dû. */
    public function clients(Request $request)
    {
        $q = Client::query()->withCount('ventes')->orderBy('nom');
        if ($s = trim((string) $request->query('q', ''))) {
            $q->where(fn ($w) => $w->where('nom', 'like', "%{$s}%")->orWhere('telephone', 'like', "%{$s}%"));
        }
        if ($request->boolean('avec_credit')) {
            $q->where('solde', '>', 0)->reorder('solde', 'desc');
        }
        $page = $q->paginate(max(1, min(200, (int) $request->query('per_page', 30))))->toArray();
        $page['stats'] = [
            'total' => Client::query()->count(),
            'avec_credit' => Client::query()->where('solde', '>', 0)->count(),
            'credit_total' => round((float) Client::query()->where('solde', '>', 0)->sum('solde'), 2),
        ];

        return response()->json($page);
    }

    /** Mouvements de stock : type (entree|sortie), motif, article_id, du, au, q. */
    public function mouvements(Request $request)
    {
        $q = MouvementStock::query()
            ->with(['article:id,nom,name_fr,code_article,image,unite', 'fournisseur:id,nom', 'utilisateur:id,nom'])
            ->latest('id');
        foreach (['type_mouvement' => 'type', 'motif' => 'motif', 'article_id' => 'article_id', 'fournisseur_id' => 'fournisseur_id'] as $col => $param) {
            if ($request->filled($param)) {
                $q->where($col, $request->query($param));
            }
        }
        if ($request->filled('du')) {
            $q->whereDate('created_at', '>=', $request->query('du'));
        }
        if ($request->filled('au')) {
            $q->whereDate('created_at', '<=', $request->query('au'));
        }
        if ($s = trim((string) $request->query('q', ''))) {
            $q->whereHas('article', fn ($a) => $a->where('nom', 'like', "%{$s}%")->orWhere('code_article', 'like', "%{$s}%"));
        }

        return response()->json($q->paginate(max(1, min(100, (int) $request->query('per_page', 30)))));
    }

    /**
     * Version de l'application mobile (publique) : l'application compare et affiche la page de mise à jour.
     * Les correctifs de code passent par Shorebird ; ceci couvre les nouvelles versions à installer.
     */
    public function version()
    {
        return response()->json([
            'version' => config('mobile.version'),
            'build' => (int) config('mobile.build'),
            'min_build' => (int) config('mobile.min_build'),
            'apk_url' => config('mobile.apk_url'),
            'notes' => config('mobile.notes'),
        ]);
    }
}
