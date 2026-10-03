<?php

namespace App\Http\Controllers\Api;

use App\Models\CommandeVente;
use App\Models\MouvementStock;
use App\Models\Stock;
use App\Models\Vente;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CommandeVenteController extends CrudController
{
    protected string $modelClass = CommandeVente::class;

    protected array $with = ['client', 'utilisateur', 'lignes.article.prix', 'vente'];

    protected array $storeRules = [
        'numero' => ['nullable', 'string', 'max:50', 'unique:commandes_vente,numero'],
        'type_commande' => ['nullable', 'in:livraison,retrait'],
        'client_id' => ['nullable', 'integer', 'exists:clients,id'],
        'statut' => ['nullable', 'string'],
        'total' => ['nullable', 'numeric'],
        'date_commande' => ['nullable', 'date'],
        'note' => ['nullable', 'string'],
        'utilisateur_id' => ['nullable', 'integer', 'exists:utilisateurs,id'],
    ];

    protected array $updateRules = [
        'numero' => ['nullable', 'string', 'max:50'],
        'type_commande' => ['nullable', 'in:livraison,retrait'],
        'client_id' => ['nullable', 'integer', 'exists:clients,id'],
        'statut' => ['nullable', 'string'],
        'total' => ['nullable', 'numeric'],
        'date_commande' => ['nullable', 'date'],
        'note' => ['nullable', 'string'],
        'utilisateur_id' => ['nullable', 'integer', 'exists:utilisateurs,id'],
    ];

    public function confirmer(string $id)
    {
        $commande = CommandeVente::query()->findOrFail($id);

        if ($commande->statut !== 'en_attente') {
            return response()->json(['message' => 'Transition invalide'], 422);
        }

        $commande->statut = 'confirmée';
        $commande->save();

        $this->logAction('confirmer', $commande->getTable(), (int) $commande->getKey());

        return response()->json($commande->fresh(['client', 'utilisateur', 'lignes']));
    }

    public function payer(Request $request, string $id)
    {
        $data = $request->validate([
            'montant_paye' => ['required', 'numeric', 'min:0'],
            'mode_paiement' => ['nullable', 'in:espèces,carte,virement,chèque'],
        ]);

        $commande = CommandeVente::query()->with('lignes')->findOrFail($id);

        if ($commande->statut !== 'confirmée') {
            return response()->json(['message' => 'La commande doit être confirmée avant paiement'], 422);
        }

        $result = DB::transaction(function () use ($commande, $data) {
            $montantTotal = 0.0;
            $montantRemise = 0.0;

            foreach ($commande->lignes as $ligne) {
                $qte = (float) $ligne->quantite;
                $pu = (float) $ligne->prix_unitaire;
                $remisePct = (float) $ligne->remise;
                $ligneTotal = $qte * $pu;
                $ligneRemise = $ligneTotal * ($remisePct / 100.0);

                $montantTotal += $ligneTotal;
                $montantRemise += $ligneRemise;

                $stock = Stock::query()->firstOrCreate(
                    ['article_id' => $ligne->article_id],
                    ['quantite' => 0, 'seuil_min' => 0]
                );

                $stock->quantite = (float) $stock->quantite - $qte;
                $stock->save();

                MouvementStock::query()->create([
                    'article_id' => $ligne->article_id,
                    'type_mouvement' => 'sortie',
                    'motif' => 'vente',
                    'quantite' => $qte,
                    'reference_id' => (int) $commande->id,
                    'reference_type' => 'vente',
                    'utilisateur_id' => $commande->utilisateur_id ?? auth()->id(),
                ]);
            }

            $vente = Vente::query()->create([
                'commande_vente_id' => $commande->id,
                'client_id' => $commande->client_id,
                'montant_total' => $montantTotal,
                'montant_remise' => $montantRemise,
                'montant_paye' => (float) $data['montant_paye'],
                'mode_paiement' => $data['mode_paiement'] ?? 'espèces',
                'date_vente' => now(),
                'utilisateur_id' => $commande->utilisateur_id ?? auth()->id(),
            ]);

            $commande->statut = 'payée';
            $commande->save();

            $this->logAction('payer', $commande->getTable(), (int) $commande->getKey(), [
                'vente_id' => $vente->id,
                'montant_total' => $montantTotal,
                'montant_remise' => $montantRemise,
                'montant_paye' => (float) $data['montant_paye'],
                'mode_paiement' => $vente->mode_paiement,
            ]);

            return $commande->fresh(['client', 'utilisateur', 'lignes.article', 'vente']);
        });

        return response()->json($result);
    }
}

