<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\HistoriqueAction;
use Illuminate\Database\QueryException;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;

abstract class CrudController extends Controller
{
    protected string $modelClass;

    protected array $with = [];

    protected array $storeRules = [];

    protected array $updateRules = [];

    public function index(Request $request)
    {
        $query = ($this->modelClass)::query();

        if ($this->with) {
            $query->with($this->with);
        }

        $perPage = (int) $request->query('per_page', 20);
        $perPage = max(1, min(1000, $perPage));

        return response()->json($query->paginate($perPage));
    }

    public function show(string $id)
    {
        $query = ($this->modelClass)::query();

        if ($this->with) {
            $query->with($this->with);
        }

        return response()->json($query->findOrFail($id));
    }

    public function store(Request $request)
    {
        $data = $this->storeRules ? $request->validate($this->storeRules) : $request->all();

        /** @var Model $model */
        $model = new $this->modelClass();
        try {
            $model->fill($data);
            $model->save();
        } catch (QueryException $e) {
            if ($this->isFkConstraint($e)) {
                return response()->json([
                    'message' => $this->fkMessage($e, $model),
                    'code' => 'FK_CONSTRAINT',
                    'constraint' => $this->extractConstraintName($e),
                ], 409);
            }
            throw $e;
        }

        $this->logAction('create', $model->getTable(), (int) $model->getKey(), $data);

        return response()->json($model, 201);
    }

    public function update(Request $request, string $id)
    {
        /** @var Model $model */
        $model = ($this->modelClass)::query()->findOrFail($id);

        $data = $this->updateRules ? $request->validate($this->updateRules) : $request->all();

        try {
            $model->fill($data);
            $model->save();
        } catch (QueryException $e) {
            if ($this->isFkConstraint($e)) {
                return response()->json([
                    'message' => $this->fkMessage($e, $model),
                    'code' => 'FK_CONSTRAINT',
                    'constraint' => $this->extractConstraintName($e),
                ], 409);
            }
            throw $e;
        }

        $this->logAction('update', $model->getTable(), (int) $model->getKey(), $data);

        return response()->json($model);
    }

    public function destroy(string $id)
    {
        /** @var Model $model */
        $model = ($this->modelClass)::query()->findOrFail($id);
        $table = $model->getTable();
        $key = (int) $model->getKey();

        try {
            $model->delete();
        } catch (QueryException $e) {
            if ($this->isFkConstraint($e)) {
                return response()->json([
                    'message' => $this->fkMessage($e, $model),
                    'code' => 'FK_CONSTRAINT',
                    'constraint' => $this->extractConstraintName($e),
                ], 409);
            }
            throw $e;
        }

        $this->logAction('delete', $table, $key);

        return response()->json(['deleted' => true]);
    }

    protected function isFkConstraint(QueryException $e): bool
    {
        $code = (int) ($e->errorInfo[1] ?? 0);
        if ($code === 1451 || $code === 1452) return true;
        $msg = (string) $e->getMessage();
        return str_contains($msg, 'Integrity constraint violation') || str_contains($msg, 'SQLSTATE[23000]');
    }

    protected function extractConstraintName(QueryException $e): ?string
    {
        $msg = (string) $e->getMessage();
        if (preg_match('/CONSTRAINT `([^`]+)`/m', $msg, $m)) {
            return (string) $m[1];
        }
        return null;
    }

    protected function fkMessage(QueryException $e, ?Model $model = null): string
    {
        $constraint = $this->extractConstraintName($e);
        $map = [
            'sous_categories_categorie_id_foreign' => "Impossible de supprimer cette catégorie : des sous-catégories y sont rattachées.",
            'articles_sous_categorie_id_foreign' => "Impossible de supprimer cette sous-catégorie : des articles y sont rattachés.",
            'prix_articles_article_id_foreign' => "Impossible de supprimer cet article : un prix est associé.",
            'stock_article_id_foreign' => "Impossible de supprimer cet article : il est lié au stock.",
            'lignes_commande_achat_article_id_foreign' => "Impossible de supprimer cet article : il est utilisé dans des commandes d'achat.",
            'lignes_commande_vente_article_id_foreign' => "Impossible de supprimer cet article : il est utilisé dans des commandes de vente.",
            'commandes_vente_client_id_foreign' => "Impossible de supprimer ce client : il est lié à des commandes de vente.",
            'commandes_achat_fournisseur_id_foreign' => "Impossible de supprimer ce fournisseur : il est lié à des commandes d'achat.",
            'lignes_commande_achat_commande_achat_id_foreign' => "Impossible de supprimer cette commande d'achat : elle contient des lignes.",
            'lignes_commande_vente_commande_vente_id_foreign' => "Impossible de supprimer cette commande de vente : elle contient des lignes.",
            'ventes_commande_vente_id_foreign' => "Impossible de supprimer cette commande : une vente est associée.",
            'utilisateurs_role_id_foreign' => "Impossible de supprimer ce rôle : des utilisateurs y sont rattachés.",
        ];

        if ($constraint && isset($map[$constraint])) return $map[$constraint];

        $table = $model?->getTable();
        if ($table === 'articles') return "Impossible de supprimer cet article : il est utilisé ailleurs (commandes, stock ou prix).";
        if ($table === 'categories') return "Impossible de supprimer cette catégorie : elle contient des éléments liés.";
        if ($table === 'clients') return "Impossible de supprimer ce client : il est utilisé dans des commandes ou ventes.";
        if ($table === 'fournisseurs') return "Impossible de supprimer ce fournisseur : il est utilisé dans des commandes d'achat.";

        return "Impossible de supprimer cet élément : il est lié à d'autres enregistrements.";
    }

    protected function logAction(string $action, string $table, ?int $recordId = null, array $details = []): void
    {
        HistoriqueAction::query()->create([
            'utilisateur_id' => auth()->id(),
            'action' => $action,
            'table_cible' => $table,
            'enregistrement_id' => $recordId,
            'details' => $details ?: null,
        ]);
    }
}
