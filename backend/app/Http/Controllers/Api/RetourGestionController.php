<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Client;
use App\Models\Fournisseur;
use App\Models\MouvementStock;
use App\Models\Retour;
use App\Models\RetourFournisseur;
use App\Models\Stock;
use App\Models\Vente;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Retours clients (marchandise rapportée par un client) et retours fournisseurs (marchandise renvoyée).
 */
class RetourGestionController extends Controller
{
    /* ===================== Retours clients ===================== */

    /** Bons de retour client (regroupés par numéro). */
    public function retoursClients(Request $request)
    {
        $q = Retour::query()->whereNotNull('numero')
            ->selectRaw('numero, vente_id, MIN(created_at) as date_retour, SUM(montant) as montant, SUM(quantite) as quantite, COUNT(*) as lignes, MAX(remboursement) as remboursement, MAX(utilisateur_id) as utilisateur_id, MAX(motif) as motif')
            ->groupBy('numero', 'vente_id')
            ->orderByDesc(DB::raw('MIN(created_at)'));
        if ($s = trim((string) $request->query('q', ''))) {
            $q->where('numero', 'like', "%{$s}%");
        }
        $page = $q->paginate(max(1, min(100, (int) $request->query('per_page', 30))))->toArray();
        $ventes = Vente::query()->with('client:id,nom', 'facture:id,vente_id,numero_facture')
            ->whereIn('id', collect($page['data'])->pluck('vente_id'))->get()->keyBy('id');
        $users = \App\Models\Utilisateur::query()->whereIn('id', collect($page['data'])->pluck('utilisateur_id')->filter())->pluck('nom', 'id');
        $page['data'] = collect($page['data'])->map(fn ($r) => $r + [
            'vente' => $ventes[$r['vente_id']] ?? null,
            'utilisateur' => isset($users[$r['utilisateur_id']]) ? ['nom' => $users[$r['utilisateur_id']]] : null,
        ])->all();
        $page['stats'] = [
            'mois_montant' => round((float) Retour::query()->where('created_at', '>=', now()->startOfMonth())->sum('montant'), 2),
            'mois_nombre' => Retour::query()->where('created_at', '>=', now()->startOfMonth())->distinct('numero')->count('numero'),
        ];

        return response()->json($page);
    }

    public function retourClient(string $numero)
    {
        $lignes = Retour::query()->where('numero', $numero)->with(['article:id,nom,name_fr,name_ar,code_article,unite,image', 'utilisateur:id,nom'])->get();
        abort_if($lignes->isEmpty(), 404, 'Retour introuvable.');
        $vente = Vente::query()->with(['client:id,nom,telephone', 'facture:id,vente_id,numero_facture'])->find($lignes->first()->vente_id);

        return response()->json([
            'numero' => $numero,
            'vente' => $vente,
            'lignes' => $lignes,
            'montant' => round($lignes->sum('montant'), 2),
            'date_retour' => $lignes->min('created_at'),
            'remboursement' => $lignes->first()->remboursement,
            'motif' => $lignes->first()->motif,
            'utilisateur' => $lignes->first()->utilisateur,
        ]);
    }

    /** Articles d'une vente avec quantités vendues, déjà retournées et retournables. */
    public function venteRetournable(int $venteId)
    {
        $vente = Vente::query()->with(['client:id,nom,solde', 'facture:id,vente_id,numero_facture', 'items.article:id,nom,name_fr,name_ar,code_article,unite,image'])
            ->findOrFail($venteId);
        $retournes = Retour::query()->where('vente_id', $venteId)->groupBy('article_id')->selectRaw('article_id, SUM(quantite) as q')->pluck('q', 'article_id');
        $lignes = $vente->items->map(fn ($l) => [
            'article_id' => $l->article_id,
            'article' => $l->article,
            'prix_unitaire' => (float) $l->prix_unitaire,
            'vendu' => (float) $l->quantite,
            'deja_retourne' => (float) ($retournes[$l->article_id] ?? 0),
            'retournable' => max(0, round((float) $l->quantite - (float) ($retournes[$l->article_id] ?? 0), 3)),
        ])->values();

        return response()->json(['vente' => $vente->only(['id', 'date_vente', 'montant_total', 'montant_paye', 'client_id', 'nom_passage']) + [
            'client' => $vente->client, 'facture' => $vente->facture,
        ], 'lignes' => $lignes]);
    }

    /**
     * Enregistre un retour client. remboursement : especes (argent rendu), credit (déduit du crédit du client), aucun.
     * en_stock : l'article retourne en rayon (sinon il est perdu / abîmé).
     */
    public function creerRetourClient(Request $request)
    {
        $data = $request->validate([
            'vente_id' => ['required', 'integer', 'exists:ventes,id'],
            'motif' => ['nullable', 'string', 'max:150'],
            'remboursement' => ['required', 'in:especes,credit,aucun'],
            'en_stock' => ['nullable', 'boolean'],
            'lignes' => ['required', 'array', 'min:1'],
            'lignes.*.article_id' => ['required', 'integer'],
            'lignes.*.quantite' => ['required', 'numeric', 'min:0'],
        ]);
        $userId = $request->user()?->id;

        $res = DB::transaction(function () use ($data, $userId) {
            $vente = Vente::query()->with('items')->lockForUpdate()->findOrFail($data['vente_id']);
            if ($data['remboursement'] === 'credit' && ! $vente->client_id) {
                throw ValidationException::withMessages(['remboursement' => 'Déduire du crédit : la vente doit avoir un client.']);
            }
            $deja = Retour::query()->where('vente_id', $vente->id)->groupBy('article_id')->selectRaw('article_id, SUM(quantite) as q')->pluck('q', 'article_id');
            $year = now()->format('Y');
            $last = Retour::query()->where('numero', 'like', "RC-{$year}-%")->max('numero');
            $numero = sprintf('RC-%s-%04d', $year, $last ? ((int) substr($last, -4)) + 1 : 1);
            $enStock = $data['en_stock'] ?? true;
            $total = 0;

            foreach ($data['lignes'] as $l) {
                $q = round((float) $l['quantite'], 3);
                if ($q <= 0) {
                    continue;
                }
                $ligne = $vente->items->firstWhere('article_id', (int) $l['article_id']);
                if (! $ligne) {
                    throw ValidationException::withMessages(['lignes' => 'Un article ne fait pas partie de cette vente.']);
                }
                $possible = round((float) $ligne->quantite - (float) ($deja[$ligne->article_id] ?? 0), 3);
                if ($q > $possible) {
                    throw ValidationException::withMessages(['lignes' => "Quantité retournée trop élevée (maximum {$possible})."]);
                }
                $montant = round($q * (float) $ligne->prix_unitaire, 2);
                $retour = Retour::query()->create([
                    'numero' => $numero,
                    'vente_id' => $vente->id,
                    'article_id' => $ligne->article_id,
                    'quantite' => $q,
                    'motif' => $data['motif'] ?? null,
                    'montant' => $montant,
                    'en_stock' => $enStock,
                    'remboursement' => $data['remboursement'],
                    'utilisateur_id' => $userId,
                ]);
                if ($enStock) {
                    Stock::query()->lockForUpdate()->firstOrCreate(['article_id' => $ligne->article_id], ['quantite' => 0, 'seuil_min' => 0])
                        ->increment('quantite', $q);
                    MouvementStock::query()->create([
                        'article_id' => $ligne->article_id, 'type_mouvement' => 'entree', 'motif' => 'retour', 'quantite' => $q,
                        'reference_id' => $retour->id, 'reference_type' => 'retour', 'utilisateur_id' => $userId, 'note' => $numero,
                    ]);
                }
                $total += $montant;
            }
            if ($total <= 0) {
                throw ValidationException::withMessages(['lignes' => 'Aucune quantité à retourner.']);
            }
            if ($data['remboursement'] === 'credit') {
                Client::query()->whereKey($vente->client_id)->decrement('solde', $total);
            }

            return ['numero' => $numero, 'montant' => round($total, 2)];
        });

        return response()->json($res, 201);
    }

    /* ===================== Retours fournisseurs ===================== */

    public function retoursFournisseurs(Request $request)
    {
        $q = RetourFournisseur::query()->with(['fournisseur:id,nom', 'reception:id,numero', 'utilisateur:id,nom'])->withCount('lignes')->latest('id');
        if ($request->filled('fournisseur_id')) {
            $q->where('fournisseur_id', $request->query('fournisseur_id'));
        }
        if ($s = trim((string) $request->query('q', ''))) {
            $q->where(fn ($w) => $w->where('numero', 'like', "%{$s}%")->orWhereHas('fournisseur', fn ($f) => $f->where('nom', 'like', "%{$s}%")));
        }
        $page = $q->paginate(max(1, min(100, (int) $request->query('per_page', 30))))->toArray();
        $page['stats'] = [
            'mois_montant' => round((float) RetourFournisseur::query()->where('date_retour', '>=', now()->startOfMonth())->sum('total'), 2),
            'mois_nombre' => RetourFournisseur::query()->where('date_retour', '>=', now()->startOfMonth())->count(),
        ];

        return response()->json($page);
    }

    public function retourFournisseur(int $id)
    {
        return response()->json(RetourFournisseur::query()
            ->with(['fournisseur', 'reception:id,numero', 'utilisateur:id,nom', 'lignes.article:id,nom,name_fr,name_ar,code_article,unite,image'])
            ->findOrFail($id));
    }

    /** Renvoi de marchandise : stock −, et avoir (crédit fournisseur −) ou remboursement. */
    public function creerRetourFournisseur(Request $request)
    {
        $data = $request->validate([
            'fournisseur_id' => ['required', 'integer', 'exists:fournisseurs,id'],
            'reception_id' => ['nullable', 'integer', 'exists:receptions,id'],
            'date_retour' => ['nullable', 'date'],
            'motif' => ['nullable', 'string', 'max:150'],
            'reglement' => ['required', 'in:avoir,remboursement'],
            'note' => ['nullable', 'string', 'max:2000'],
            'lignes' => ['required', 'array', 'min:1'],
            'lignes.*.article_id' => ['required', 'integer', 'exists:articles,id'],
            'lignes.*.quantite' => ['required', 'numeric', 'gt:0'],
            'lignes.*.prix_achat' => ['required', 'numeric', 'min:0'],
        ]);
        $userId = $request->user()?->id;

        $retour = DB::transaction(function () use ($data, $userId) {
            $fournisseur = Fournisseur::query()->lockForUpdate()->findOrFail($data['fournisseur_id']);
            $year = now()->format('Y');
            $last = RetourFournisseur::query()->where('numero', 'like', "RF-{$year}-%")->lockForUpdate()->max('numero');
            $total = round(collect($data['lignes'])->sum(fn ($l) => (float) $l['quantite'] * (float) $l['prix_achat']), 2);
            $retour = RetourFournisseur::query()->create([
                'numero' => sprintf('RF-%s-%04d', $year, $last ? ((int) substr($last, -4)) + 1 : 1),
                'fournisseur_id' => $fournisseur->id,
                'reception_id' => $data['reception_id'] ?? null,
                'date_retour' => $data['date_retour'] ?? now()->toDateString(),
                'motif' => $data['motif'] ?? null,
                'total' => $total,
                'reglement' => $data['reglement'],
                'note' => $data['note'] ?? null,
                'utilisateur_id' => $userId,
            ]);
            foreach ($data['lignes'] as $l) {
                $stock = Stock::query()->lockForUpdate()->firstOrCreate(['article_id' => $l['article_id']], ['quantite' => 0, 'seuil_min' => 0]);
                if ((float) $stock->quantite < (float) $l['quantite']) {
                    throw ValidationException::withMessages(['lignes' => 'Stock insuffisant pour renvoyer un des articles.']);
                }
                $retour->lignes()->create($l);
                $stock->decrement('quantite', $l['quantite']);
                MouvementStock::query()->create([
                    'article_id' => $l['article_id'], 'fournisseur_id' => $fournisseur->id, 'type_mouvement' => 'sortie', 'motif' => 'retour',
                    'quantite' => $l['quantite'], 'reference_id' => $retour->id, 'reference_type' => 'retour_fournisseur',
                    'utilisateur_id' => $userId, 'note' => $retour->numero,
                ]);
            }
            // Avoir : la somme est déduite de ce que l'on doit au fournisseur.
            if ($data['reglement'] === 'avoir') {
                $fournisseur->decrement('solde', $total);
            }

            return $retour;
        });

        return response()->json($retour->load(['fournisseur:id,nom', 'lignes.article:id,nom,code_article']), 201);
    }
}
