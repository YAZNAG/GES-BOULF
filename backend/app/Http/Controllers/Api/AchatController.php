<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CommandeAchat;
use App\Models\Fournisseur;
use App\Models\PaiementFournisseur;
use App\Models\Reception;
use App\Services\AchatService;
use Illuminate\Http\Request;

/**
 * Achats : bons de commande, bons de réception, règlements et relevé fournisseur.
 */
class AchatController extends Controller
{
    public function __construct(private AchatService $achats) {}

    /* ---------------- Bons de commande ---------------- */

    public function commandes(Request $request)
    {
        $q = CommandeAchat::query()->with('fournisseur:id,nom')->withCount('lignes')->latest('id');
        if ($request->filled('statut')) {
            $q->where('statut', $request->query('statut'));
        }
        if ($request->filled('fournisseur_id')) {
            $q->where('fournisseur_id', $request->query('fournisseur_id'));
        }
        if ($s = trim((string) $request->query('q', ''))) {
            $q->where(fn ($w) => $w->where('numero', 'like', "%{$s}%")
                ->orWhereHas('fournisseur', fn ($f) => $f->where('nom', 'like', "%{$s}%")));
        }
        $page = $q->paginate(max(1, min(200, (int) $request->query('per_page', 30))))->toArray();
        $page['stats'] = CommandeAchat::query()->selectRaw('statut, count(*) as n, sum(total) as montant')->groupBy('statut')->get()->keyBy('statut');

        return response()->json($page);
    }

    public function commande(int $id)
    {
        return response()->json(CommandeAchat::query()
            ->with(['fournisseur', 'lignes.article.prix', 'lignes.article.stock', 'receptions:id,numero,commande_achat_id,date_reception,total', 'utilisateur:id,nom'])
            ->findOrFail($id));
    }

    public function enregistrerCommande(Request $request, ?int $id = null)
    {
        $data = $request->validate([
            'fournisseur_id' => ['required', 'integer', 'exists:fournisseurs,id'],
            'date_commande' => ['nullable', 'date'],
            'date_prevue' => ['nullable', 'date'],
            'note' => ['nullable', 'string', 'max:2000'],
            'lignes' => ['required', 'array', 'min:1'],
            'lignes.*.article_id' => ['required', 'integer', 'exists:articles,id'],
            'lignes.*.quantite' => ['required', 'numeric', 'gt:0'],
            'lignes.*.prix_unitaire' => ['nullable', 'numeric', 'min:0'],
        ]);
        $commande = $id ? CommandeAchat::query()->findOrFail($id) : null;

        return response()->json($this->achats->enregistrerCommande($commande, $data, $request->user()?->id), $id ? 200 : 201);
    }

    public function statutCommande(Request $request, int $id)
    {
        $data = $request->validate(['statut' => ['required', 'in:confirmee,annulee,brouillon']]);

        return response()->json($this->achats->changerStatut(CommandeAchat::query()->findOrFail($id), $data['statut']));
    }

    public function supprimerCommande(int $id)
    {
        $commande = CommandeAchat::query()->findOrFail($id);
        abort_if($commande->statut !== 'brouillon', 422, 'Seul un brouillon peut être supprimé.');
        $commande->delete();

        return response()->json(['deleted' => true]);
    }

    /* ---------------- Bons de réception ---------------- */

    public function receptions(Request $request)
    {
        $q = Reception::query()->with(['fournisseur:id,nom', 'commande:id,numero'])->withCount('lignes')->latest('id');
        if ($request->filled('fournisseur_id')) {
            $q->where('fournisseur_id', $request->query('fournisseur_id'));
        }
        if ($request->filled('du')) {
            $q->whereDate('date_reception', '>=', $request->query('du'));
        }
        if ($request->filled('au')) {
            $q->whereDate('date_reception', '<=', $request->query('au'));
        }
        if ($request->query('impaye')) {
            $q->whereColumn('montant_paye', '<', 'total');
        }
        if ($s = trim((string) $request->query('q', ''))) {
            $q->where(fn ($w) => $w->where('numero', 'like', "%{$s}%")->orWhere('reference_fournisseur', 'like', "%{$s}%")
                ->orWhereHas('fournisseur', fn ($f) => $f->where('nom', 'like', "%{$s}%")));
        }
        $page = $q->paginate(max(1, min(200, (int) $request->query('per_page', 30))))->toArray();
        $mois = Reception::query()->whereBetween('date_reception', [now()->startOfMonth(), now()->endOfMonth()]);
        $page['stats'] = [
            'mois_nombre' => (clone $mois)->count(),
            'mois_montant' => (float) (clone $mois)->sum('total'),
            'credit_total' => (float) Fournisseur::query()->sum('solde'),
        ];

        return response()->json($page);
    }

    public function reception(int $id)
    {
        return response()->json(Reception::query()
            ->with(['fournisseur', 'commande:id,numero', 'lignes.article:id,nom,name_fr,name_ar,code_article,unite,image', 'utilisateur:id,nom'])
            ->findOrFail($id));
    }

    public function receptionner(Request $request)
    {
        $data = $request->validate([
            'fournisseur_id' => ['required', 'integer', 'exists:fournisseurs,id'],
            'commande_achat_id' => ['nullable', 'integer', 'exists:commandes_achat,id'],
            'date_reception' => ['nullable', 'date'],
            'reference_fournisseur' => ['nullable', 'string', 'max:60'],
            'note' => ['nullable', 'string', 'max:2000'],
            'montant_paye' => ['nullable', 'numeric', 'min:0'],
            'mode_paiement' => ['nullable', 'string', 'max:30'],
            'lignes' => ['required', 'array', 'min:1'],
            'lignes.*.article_id' => ['required', 'integer', 'exists:articles,id'],
            'lignes.*.quantite' => ['required', 'numeric', 'min:0'],
            'lignes.*.prix_achat' => ['required', 'numeric', 'min:0'],
            'lignes.*.prix_vente' => ['nullable', 'numeric', 'min:0'],
            'lignes.*.ligne_commande_achat_id' => ['nullable', 'integer'],
        ]);

        return response()->json($this->achats->receptionner($data, $request->user()?->id), 201);
    }

    /* ---------------- Règlements et relevé ---------------- */

    public function paiements(Request $request)
    {
        $q = PaiementFournisseur::query()->with(['fournisseur:id,nom', 'reception:id,numero'])->latest('date_paiement')->latest('id');
        if ($request->filled('fournisseur_id')) {
            $q->where('fournisseur_id', $request->query('fournisseur_id'));
        }

        return response()->json($q->paginate(max(1, min(200, (int) $request->query('per_page', 30)))));
    }

    public function payer(Request $request)
    {
        $data = $request->validate([
            'fournisseur_id' => ['required', 'integer', 'exists:fournisseurs,id'],
            'reception_id' => ['nullable', 'integer', 'exists:receptions,id'],
            'montant' => ['required', 'numeric', 'gt:0'],
            'mode' => ['nullable', 'string', 'max:30'],
            'date_paiement' => ['nullable', 'date'],
            'reference' => ['nullable', 'string', 'max:60'],
            'note' => ['nullable', 'string', 'max:2000'],
        ]);

        return response()->json($this->achats->payer($data, $request->user()?->id), 201);
    }

    public function releve(int $id)
    {
        $fournisseur = Fournisseur::query()->findOrFail($id);

        return response()->json([
            'fournisseur' => $fournisseur,
            'lignes' => $this->achats->releve($fournisseur),
        ]);
    }
}
