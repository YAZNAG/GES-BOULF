<?php

namespace App\Support;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Où un élément est-il utilisé ? Sert à n'autoriser la suppression que d'un élément jamais utilisé
 * (sinon on propose de le désactiver), pour ne jamais perdre d'historique.
 */
class Utilisation
{
    /** type => [libellé => [table, colonne]] */
    private const REFERENCES = [
        'articles' => [
            'ventes' => ['lignes_commande_vente', 'article_id'],
            'bons de commande' => ['lignes_commande_achat', 'article_id'],
            'réceptions' => ['lignes_reception', 'article_id'],
            'mouvements de stock' => ['mouvements_stock', 'article_id'],
            'inventaires' => ['lignes_inventaire', 'article_id'],
            'retours clients' => ['retours', 'article_id'],
            'retours fournisseurs' => ['lignes_retour_fournisseur', 'article_id'],
            'packs' => ['pack_items', 'article_id'],
            'sorties' => ['sorties', 'article_id'],
        ],
        'clients' => [
            'ventes' => ['ventes', 'client_id'],
            'commandes' => ['commandes_vente', 'client_id'],
            'paiements' => ['paiements', 'client_id'],
        ],
        'fournisseurs' => [
            'bons de commande' => ['commandes_achat', 'fournisseur_id'],
            'réceptions' => ['receptions', 'fournisseur_id'],
            'règlements' => ['paiements_fournisseur', 'fournisseur_id'],
            'retours fournisseurs' => ['retours_fournisseur', 'fournisseur_id'],
            'mouvements de stock' => ['mouvements_stock', 'fournisseur_id'],
        ],
        'utilisateurs' => [
            'ventes' => ['ventes', 'utilisateur_id'],
            'réceptions' => ['receptions', 'utilisateur_id'],
            'bons de commande' => ['commandes_achat', 'utilisateur_id'],
            'mouvements de stock' => ['mouvements_stock', 'utilisateur_id'],
            'charges' => ['charges', 'utilisateur_id'],
            'inventaires' => ['inventaires', 'utilisateur_id'],
            'paiements' => ['paiements', 'utilisateur_id'],
        ],
        'marques' => ['produits' => ['articles', 'marque_id']],
        'categories_charges' => ['charges' => ['charges', 'categorie_charge_id']],
    ];

    /** [libellé => nombre] pour les usages non nuls. */
    public static function de(string $type, int $id): array
    {
        $out = [];
        foreach (self::REFERENCES[$type] ?? [] as $label => [$table, $col]) {
            if (! Schema::hasTable($table) || ! Schema::hasColumn($table, $col)) {
                continue;
            }
            $n = DB::table($table)->where($col, $id)->count();
            if ($n > 0) {
                $out[$label] = $n;
            }
        }

        return $out;
    }

    /** Réponse 409 lisible : « Utilisé dans 12 ventes, 3 réceptions… — désactivez-le plutôt. » */
    public static function refus(string $quoi, array $usages, bool $desactivable = true): \Illuminate\Http\JsonResponse
    {
        $detail = collect($usages)->map(fn ($n, $l) => "{$n} {$l}")->implode(', ');

        return response()->json([
            'message' => "Impossible de supprimer {$quoi} : utilisé dans {$detail}.".($desactivable ? ' Vous pouvez le désactiver à la place.' : ''),
            'code' => 'EN_UTILISATION',
            'utilisations' => $usages,
            'desactivable' => $desactivable,
        ], 409);
    }
}
