<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Article;
use App\Models\Client;
use App\Models\MouvementStock;
use App\Models\Retour;
use App\Models\Stock;
use App\Models\Vente;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class RetourController extends Controller
{
    public function store(Request $request)
    {
        $request->validate([
            'vente_id' => 'required|exists:ventes,id',
            'article_id' => 'required|exists:articles,id',
            'quantite' => 'required|numeric|min:0.001',
            'motif' => 'nullable|string|max:150',
        ]);

        try {
            return DB::transaction(function () use ($request) {
                $vente = Vente::findOrFail($request->vente_id);
                $article = Article::findOrFail($request->article_id);
                $userId = auth()->id() ?? 1;

                // 1. Calculate amount to return
                // We need to find the unit price from the sale items
                $ligne = $vente->items()->where('article_id', $article->id)->first();
                if (!$ligne) {
                    throw new \Exception("Cet article n'existe pas dans cette vente.");
                }

                if ($request->quantite > $ligne->quantite) {
                    throw new \Exception("La quantité retournée est supérieure à la quantité vendue.");
                }

                $montantRetour = $request->quantite * $ligne->prix_unitaire;

                // 2. Create Retour record
                $retour = Retour::create([
                    'vente_id' => $vente->id,
                    'article_id' => $article->id,
                    'quantite' => $request->quantite,
                    'motif' => $request->motif,
                    'montant' => $montantRetour,
                    'utilisateur_id' => $userId,
                ]);

                // 3. Update Stock
                $stock = Stock::firstOrCreate(['article_id' => $article->id], ['quantite' => 0]);
                $stock->increment('quantite', $request->quantite);

                // 4. Create MouvementStock
                MouvementStock::create([
                    'article_id' => $article->id,
                    'type_mouvement' => 'entree',
                    'motif' => 'retour',
                    'quantite' => $request->quantite,
                    'reference_id' => $retour->id,
                    'reference_type' => 'retour',
                    'utilisateur_id' => $userId,
                ]);

                // 5. Adjust Client Balance if it was a credit sale or if they have a balance
                if ($vente->client_id) {
                    $client = Client::find($vente->client_id);
                    // If the client has a debt, we reduce it first
                    if ($client->solde > 0) {
                        $reduction = min($client->solde, $montantRetour);
                        $client->decrement('solde', $reduction);
                    }
                }

                return response()->json([
                    'success' => true,
                    'message' => 'Retour enregistré avec succès.',
                    'retour' => $retour
                ], 201);
            });
        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }
}
