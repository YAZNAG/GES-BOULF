<?php

namespace App\Http\Controllers\Api;

use App\Models\Article;
use App\Models\Unite;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class UniteController extends CrudController
{
    protected string $modelClass = Unite::class;

    protected array $storeRules = [
        'nom' => ['required', 'string', 'max:20', 'unique:unites,nom'],
        'description' => ['nullable', 'string'],
        'actif' => ['nullable', 'boolean'],
    ];

    protected array $updateRules = [
        'nom' => ['sometimes', 'required', 'string', 'max:20'],
        'description' => ['nullable', 'string'],
        'actif' => ['nullable', 'boolean'],
    ];

    public function update(Request $request, string $id)
    {
        $model = ($this->modelClass)::query()->findOrFail($id);

        $rules = $this->updateRules;
        $rules['nom'] = [
            'sometimes',
            'required',
            'string',
            'max:20',
            Rule::unique('unites', 'nom')->ignore($model->id),
        ];

        $data = $request->validate($rules);
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
        /** @var Unite $model */
        $model = ($this->modelClass)::query()->findOrFail($id);

        $used = Article::query()->where('unite', $model->nom)->exists();
        if ($used) {
            return response()->json([
                'message' => "Impossible de supprimer cette unité : elle est utilisée par des articles.",
                'code' => 'UNIT_IN_USE',
            ], 409);
        }

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

        $this->logAction('delete', $model->getTable(), (int) $model->getKey());

        return response()->json(['deleted' => true]);
    }
}
