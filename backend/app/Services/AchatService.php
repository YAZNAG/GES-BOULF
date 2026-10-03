<?php

namespace App\Services;

use App\Models\Article;
use App\Models\CommandeAchat;
use App\Models\Fournisseur;
use App\Models\LigneCommandeAchat;
use App\Models\MouvementStock;
use App\Models\PaiementFournisseur;
use App\Models\PrixArticle;
use App\Models\Reception;
use App\Models\Stock;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Règles métier des achats :
 *  - bon de commande : brouillon → confirmée → (partielle) → reçue, ou annulée ;
 *  - bon de réception : entre les quantités en stock, fixe le prix d'achat (et éventuellement le prix de vente),
 *    met à jour le bon de commande lié et augmente le crédit fournisseur du montant non payé ;
 *  - règlement : diminue le crédit fournisseur.
 */
class AchatService
{
    private const MODES = ['especes' => 'en espèces', 'cheque' => 'par chèque', 'virement' => 'par virement', 'effet' => 'par effet', 'carte' => 'par carte'];

    /** Numéro lisible et unique : BC-2026-0001, BR-2026-0001… */
    public function numero(string $prefix, string $table): string
    {
        $year = now()->format('Y');
        $last = DB::table($table)->where('numero', 'like', "{$prefix}-{$year}-%")->lockForUpdate()->max('numero');
        $next = $last ? ((int) substr($last, -4)) + 1 : 1;

        return sprintf('%s-%s-%04d', $prefix, $year, $next);
    }

    /** Crée ou remplace les lignes d'un bon de commande (seulement au statut brouillon). */
    public function enregistrerCommande(?CommandeAchat $commande, array $data, ?int $userId): CommandeAchat
    {
        return DB::transaction(function () use ($commande, $data, $userId) {
            if ($commande && $commande->statut !== 'brouillon') {
                throw ValidationException::withMessages(['statut' => 'Seul un bon de commande en brouillon peut être modifié.']);
            }
            $commande ??= new CommandeAchat([
                'numero' => $this->numero('BC', 'commandes_achat'),
                'statut' => 'brouillon',
                'utilisateur_id' => $userId,
            ]);
            $commande->fill([
                'fournisseur_id' => $data['fournisseur_id'],
                'date_commande' => $data['date_commande'] ?? now()->toDateString(),
                'date_prevue' => $data['date_prevue'] ?? null,
                'note' => $data['note'] ?? null,
            ]);
            $commande->total = collect($data['lignes'])->sum(fn ($l) => (float) $l['quantite'] * (float) ($l['prix_unitaire'] ?? 0));
            $commande->save();

            $commande->lignes()->delete();
            foreach ($data['lignes'] as $l) {
                $commande->lignes()->create([
                    'article_id' => $l['article_id'],
                    'quantite' => $l['quantite'],
                    'prix_unitaire' => $l['prix_unitaire'] ?? 0,
                ]);
            }

            return $commande->load(['fournisseur', 'lignes.article']);
        });
    }

    public function changerStatut(CommandeAchat $commande, string $statut): CommandeAchat
    {
        $permis = [
            'confirmee' => ['brouillon'],
            'annulee' => ['brouillon', 'confirmee'],
            'brouillon' => ['confirmee'],
        ];
        if (! in_array($commande->statut, $permis[$statut] ?? [], true)) {
            throw ValidationException::withMessages(['statut' => "Passage impossible de « {$commande->statut} » à « {$statut} »."]);
        }
        if ($statut === 'brouillon' && $commande->lignes()->where('quantite_recue', '>', 0)->exists()) {
            throw ValidationException::withMessages(['statut' => 'Ce bon de commande a déjà des réceptions.']);
        }
        $commande->update(['statut' => $statut]);

        return $commande;
    }

    /**
     * Valide un bon de réception.
     * $data : fournisseur_id, commande_achat_id?, date_reception?, reference_fournisseur?, note?,
     *         montant_paye?, mode_paiement?, lignes[{article_id, quantite, prix_achat, prix_vente?, ligne_commande_achat_id?}]
     */
    public function receptionner(array $data, ?int $userId): Reception
    {
        return DB::transaction(function () use ($data, $userId) {
            $fournisseur = Fournisseur::query()->lockForUpdate()->findOrFail($data['fournisseur_id']);
            $commande = null;
            if (! empty($data['commande_achat_id'])) {
                $commande = CommandeAchat::query()->lockForUpdate()->findOrFail($data['commande_achat_id']);
                if (! in_array($commande->statut, ['confirmee', 'partielle'], true)) {
                    throw ValidationException::withMessages(['commande_achat_id' => 'Le bon de commande doit être confirmé pour être réceptionné.']);
                }
                if ((int) $commande->fournisseur_id !== (int) $fournisseur->id) {
                    throw ValidationException::withMessages(['fournisseur_id' => 'Le fournisseur ne correspond pas au bon de commande.']);
                }
            }

            $lignes = collect($data['lignes'])->filter(fn ($l) => (float) $l['quantite'] > 0)->values();
            if ($lignes->isEmpty()) {
                throw ValidationException::withMessages(['lignes' => 'Aucune quantité reçue.']);
            }
            $total = round($lignes->sum(fn ($l) => (float) $l['quantite'] * (float) $l['prix_achat']), 2);
            $paye = min(round((float) ($data['montant_paye'] ?? 0), 2), $total);

            $reception = Reception::query()->create([
                'numero' => $this->numero('BR', 'receptions'),
                'fournisseur_id' => $fournisseur->id,
                'commande_achat_id' => $commande?->id,
                'date_reception' => $data['date_reception'] ?? now()->toDateString(),
                'reference_fournisseur' => $data['reference_fournisseur'] ?? null,
                'total' => $total,
                'montant_paye' => $paye,
                'mode_paiement' => $paye > 0 ? ($data['mode_paiement'] ?? 'especes') : null,
                'note' => $data['note'] ?? null,
                'utilisateur_id' => $userId,
            ]);

            foreach ($lignes as $l) {
                $ligneCommande = null;
                if ($commande && ! empty($l['ligne_commande_achat_id'])) {
                    $ligneCommande = LigneCommandeAchat::query()
                        ->where('commande_achat_id', $commande->id)
                        ->find($l['ligne_commande_achat_id']);
                }
                $reception->lignes()->create([
                    'article_id' => $l['article_id'],
                    'ligne_commande_achat_id' => $ligneCommande?->id,
                    'quantite' => $l['quantite'],
                    'prix_achat' => $l['prix_achat'],
                    'prix_vente' => isset($l['prix_vente']) && $l['prix_vente'] !== '' ? $l['prix_vente'] : null,
                ]);
                $ligneCommande?->increment('quantite_recue', $l['quantite']);

                // Entrée en stock + traçabilité
                $stock = Stock::query()->lockForUpdate()->firstOrCreate(['article_id' => $l['article_id']], ['quantite' => 0, 'seuil_min' => 0]);
                $stock->increment('quantite', $l['quantite']);
                MouvementStock::query()->create([
                    'article_id' => $l['article_id'],
                    'fournisseur_id' => $fournisseur->id,
                    'type_mouvement' => 'entree',
                    'motif' => 'achat',
                    'quantite' => $l['quantite'],
                    'reference_id' => $reception->id,
                    'reference_type' => 'reception',
                    'utilisateur_id' => $userId,
                    'note' => $reception->numero,
                ]);

                // Le prix d'achat est fixé à la réception ; le prix de vente peut l'être aussi.
                $prix = PrixArticle::query()->firstOrNew(['article_id' => $l['article_id']]);
                $prix->prix_achat = $l['prix_achat'];
                if (isset($l['prix_vente']) && (float) $l['prix_vente'] > 0) {
                    $prix->prix_vente = $l['prix_vente'];
                    if (! $prix->prix_gros || (float) $prix->prix_gros <= 0) {
                        $prix->prix_gros = $l['prix_vente'];
                    }
                }
                $prix->prix_vente ??= 0;
                $prix->save();

                // Article reçu et tarifé : il devient vendable.
                if ((float) $prix->prix_vente > 0) {
                    Article::query()->whereKey($l['article_id'])->update(['actif' => true]);
                }
            }

            if ($commande) {
                $restant = $commande->lignes()->whereColumn('quantite_recue', '<', 'quantite')->exists();
                $commande->update([
                    'statut' => $restant ? 'partielle' : 'recue',
                    'date_reception' => $reception->date_reception,
                ]);
            }

            // Crédit fournisseur : ce qui n'est pas payé maintenant est dû.
            $fournisseur->increment('solde', $total - $paye);
            if ($paye > 0) {
                PaiementFournisseur::query()->create([
                    'fournisseur_id' => $fournisseur->id,
                    'reception_id' => $reception->id,
                    'montant' => $paye,
                    'mode' => $data['mode_paiement'] ?? 'especes',
                    'date_paiement' => $reception->date_reception,
                    'note' => 'Paiement à la réception '.$reception->numero,
                    'utilisateur_id' => $userId,
                ]);
            }

            return $reception->load(['fournisseur', 'commande', 'lignes.article']);
        });
    }

    /** Règlement d'un fournisseur (diminue son crédit). */
    public function payer(array $data, ?int $userId): PaiementFournisseur
    {
        return DB::transaction(function () use ($data, $userId) {
            $fournisseur = Fournisseur::query()->lockForUpdate()->findOrFail($data['fournisseur_id']);
            $paiement = PaiementFournisseur::query()->create([
                'fournisseur_id' => $fournisseur->id,
                'reception_id' => $data['reception_id'] ?? null,
                'montant' => $data['montant'],
                'mode' => $data['mode'] ?? 'especes',
                'date_paiement' => $data['date_paiement'] ?? now()->toDateString(),
                'reference' => $data['reference'] ?? null,
                'note' => $data['note'] ?? null,
                'utilisateur_id' => $userId,
            ]);
            if (! empty($data['reception_id'])) {
                Reception::query()->whereKey($data['reception_id'])->where('fournisseur_id', $fournisseur->id)
                    ->update(['montant_paye' => DB::raw('LEAST(total, montant_paye + '.(float) $data['montant'].')')]);
            }
            $fournisseur->decrement('solde', $data['montant']);

            return $paiement;
        });
    }

    /** Relevé du fournisseur : réceptions (dû) et règlements (payé), avec solde courant. */
    public function releve(Fournisseur $fournisseur): array
    {
        $lignes = collect();
        foreach ($fournisseur->receptions()->orderBy('date_reception')->get() as $r) {
            $lignes->push(['date' => $r->date_reception->toDateString(), 'type' => 'reception', 'id' => $r->id,
                'libelle' => 'Réception '.$r->numero.($r->reference_fournisseur ? ' (BL '.$r->reference_fournisseur.')' : ''),
                'debit' => (float) $r->total, 'credit' => 0.0, 'tri' => $r->created_at]);
        }
        foreach ($fournisseur->paiements()->orderBy('date_paiement')->get() as $p) {
            $lignes->push(['date' => $p->date_paiement->toDateString(), 'type' => 'paiement', 'id' => $p->id,
                'libelle' => 'Règlement '.(self::MODES[$p->mode] ?? $p->mode).($p->reference ? ' n° '.$p->reference : ''),
                'debit' => 0.0, 'credit' => (float) $p->montant, 'tri' => $p->created_at]);
        }
        $solde = 0.0;

        return $lignes->sortBy([['date', 'asc'], ['tri', 'asc']])->values()->map(function ($l) use (&$solde) {
            $solde = round($solde + $l['debit'] - $l['credit'], 2);
            unset($l['tri']);

            return $l + ['solde' => $solde];
        })->all();
    }
}
