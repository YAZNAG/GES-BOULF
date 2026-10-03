<?php

namespace App\Http\Controllers\Api;

use App\Models\Pack;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class PackController extends CrudController
{
    protected string $modelClass = Pack::class;

    protected array $with = ['items.article.prix', 'items.article.stock', 'items.article.sousCategorie.categorie'];

    public function store(Request $request)
    {
        $data = $request->validate([
            'nom' => ['required', 'string', 'max:150', 'unique:packs,nom'],
            'description' => ['nullable', 'string'],
            'prix_vente' => ['required', 'numeric', 'min:0'],
            'image' => ['nullable', 'string', 'max:255'],
            'actif' => ['nullable', 'boolean'],
            'items' => ['nullable', 'array'],
            'items.*.article_id' => ['required_with:items', 'integer', 'exists:articles,id'],
            'items.*.quantite' => ['required_with:items', 'numeric', 'gt:0'],
        ]);

        /** @var Pack $pack */
        $pack = new $this->modelClass();

        try {
            DB::transaction(function () use (&$pack, $data) {
                $items = $data['items'] ?? [];
                unset($data['items']);

                $pack->fill($data);
                $pack->save();

                foreach ($items as $it) {
                    $pack->items()->create([
                        'article_id' => (int) $it['article_id'],
                        'quantite' => (float) $it['quantite'],
                    ]);
                }
            });
        } catch (QueryException $e) {
            if ($this->isFkConstraint($e)) {
                return response()->json([
                    'message' => $this->fkMessage($e, $pack),
                    'code' => 'FK_CONSTRAINT',
                    'constraint' => $this->extractConstraintName($e),
                ], 409);
            }
            throw $e;
        }

        $this->logAction('create', $pack->getTable(), (int) $pack->getKey(), $data);

        $pack->load($this->with);
        return response()->json($pack, 201);
    }

    public function update(Request $request, string $id)
    {
        /** @var Pack $pack */
        $pack = ($this->modelClass)::query()->findOrFail($id);

        $data = $request->validate([
            'nom' => ['sometimes', 'required', 'string', 'max:150', Rule::unique('packs', 'nom')->ignore($pack->id)],
            'description' => ['nullable', 'string'],
            'prix_vente' => ['sometimes', 'required', 'numeric', 'min:0'],
            'image' => ['nullable', 'string', 'max:255'],
            'actif' => ['nullable', 'boolean'],
            'items' => ['nullable', 'array'],
            'items.*.article_id' => ['required_with:items', 'integer', 'exists:articles,id'],
            'items.*.quantite' => ['required_with:items', 'numeric', 'gt:0'],
        ]);

        try {
            DB::transaction(function () use (&$pack, $data) {
                $items = $data['items'] ?? null;
                unset($data['items']);

                $pack->fill($data);
                $pack->save();

                if (is_array($items)) {
                    $pack->items()->delete();
                    foreach ($items as $it) {
                        $pack->items()->create([
                            'article_id' => (int) $it['article_id'],
                            'quantite' => (float) $it['quantite'],
                        ]);
                    }
                }
            });
        } catch (QueryException $e) {
            if ($this->isFkConstraint($e)) {
                return response()->json([
                    'message' => $this->fkMessage($e, $pack),
                    'code' => 'FK_CONSTRAINT',
                    'constraint' => $this->extractConstraintName($e),
                ], 409);
            }
            throw $e;
        }

        $this->logAction('update', $pack->getTable(), (int) $pack->getKey(), $data);

        $pack->load($this->with);
        return response()->json($pack);
    }
}

