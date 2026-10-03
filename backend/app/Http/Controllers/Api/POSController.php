<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Client;
use App\Models\CommandeVente;
use App\Models\Facture;
use App\Models\LigneCommandeVente;
use App\Models\MouvementStock;
use App\Models\Stock;
use App\Models\Vente;
use App\Models\Paiement;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class POSController extends Controller
{
    public function store(Request $request)
    {
        $request->validate([
            'client_id' => 'nullable|exists:clients,id',
            'items' => 'required|array|min:1',
            'items.*.article_id' => 'required|exists:articles,id',
            'items.*.quantite' => 'required|numeric|min:0.01',
            'items.*.prix_unitaire' => 'required|numeric|min:0',
            'montant_total' => 'required|numeric|min:0',
            'montant_paye' => 'required|numeric|min:0',
            'mode_paiement' => 'required|string',
        ]);

        // Le montant remis au-delà du total est de la monnaie rendue, pas un encaissement.
        $request->merge(['montant_paye' => min((float) $request->montant_paye, (float) $request->montant_total)]);

        try {
            $result = DB::transaction(function () use ($request) {
                $userId = auth()->id() ?? 1; // Fallback to 1 for testing if not authenticated

                // 1. Create CommandeVente
                // Note: The database might have constraints on these columns if migrations failed.
                // We use 'livraison' as a safer default if 'directe' is not allowed, 
                // but usually 'directe' should be allowed after migration.
                $commande = CommandeVente::create([
                    'type_commande' => 'directe', 
                    'client_id' => $request->client_id,
                    'statut' => 'livrée',
                    'total' => $request->montant_total,
                    'date_commande' => now(),
                    'utilisateur_id' => $userId,
                ]);

                // 2. Create LigneCommandeVente and Update Stock
                foreach ($request->items as $item) {
                    LigneCommandeVente::create([
                        'commande_vente_id' => $commande->id,
                        'article_id' => $item['article_id'],
                        'quantite' => $item['quantite'],
                        'prix_unitaire' => $item['prix_unitaire'],
                        'remise' => 0,
                    ]);

                    // Update Stock
                    $stock = Stock::firstOrCreate(
                        ['article_id' => $item['article_id']],
                        ['quantite' => 0, 'seuil_min' => 0]
                    );
                    $stock->decrement('quantite', $item['quantite']);

                    // Create MouvementStock
                    MouvementStock::create([
                        'article_id' => $item['article_id'],
                        'type_mouvement' => 'sortie',
                        'motif' => 'vente',
                        'quantite' => $item['quantite'],
                        'reference_id' => $commande->id,
                        'reference_type' => 'commande_vente',
                        'utilisateur_id' => $userId,
                    ]);
                }

                // 3. Create Vente
                $vente = Vente::create([
                    'commande_vente_id' => $commande->id,
                    'client_id' => $request->client_id,
                    'montant_total' => $request->montant_total,
                    'montant_remise' => 0,
                    'montant_paye' => $request->montant_paye,
                    'mode_paiement' => $request->montant_paye < $request->montant_total ? 'credit' : $request->mode_paiement,
                    'date_vente' => now(),
                    'utilisateur_id' => $userId,
                ]);

                // 4. Handle Client Credit and Payments
                if ($request->client_id) {
                    $client = Client::find($request->client_id);
                    $reste = $request->montant_total - $request->montant_paye;
                    
                    if ($reste > 0) {
                        $client->increment('solde', $reste);
                    }

                    if ($request->montant_paye > 0) {
                        Paiement::create([
                            'client_id' => $request->client_id,
                            'vente_id' => $vente->id,
                            'montant' => $request->montant_paye,
                            'mode' => $request->mode_paiement,
                            'note' => 'Paiement vente POS',
                            'utilisateur_id' => $userId,
                        ]);
                    }
                }

                // 5. Create Facture
                $latestFacture = Facture::orderBy('id', 'desc')->first();
                $nextId = $latestFacture ? $latestFacture->id + 1 : 1;
                $numeroFacture = 'FAC-' . date('Y') . '-' . str_pad($nextId, 4, '0', STR_PAD_LEFT);

                $facture = Facture::create([
                    'vente_id' => $vente->id,
                    'numero_facture' => $numeroFacture,
                    'date_facture' => now(),
                    'montant_ttc' => $request->montant_total,
                    'statut' => $request->montant_paye >= $request->montant_total ? 'payée' : 'en_attente',
                ]);

                return [
                    'success' => true,
                    'commande_id' => $commande->id,
                    'vente_id' => $vente->id,
                    'facture_id' => $facture->id,
                    'numero_facture' => $numeroFacture
                ];
            });

            return response()->json($result, 201);
        } catch (\Exception $e) {
            Log::error('POS Sale Error: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Erreur lors de la validation de la vente: ' . $e->getMessage()
            ], 500);
        }
    }
}
