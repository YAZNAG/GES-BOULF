<?php

namespace App\Http\Controllers\Api;

use App\Models\Article;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class ArticleController extends CrudController
{
    protected string $modelClass = Article::class;

    protected array $with = ['sousCategorie', 'marque', 'prix', 'stock'];

    protected array $storeRules = [
        'sous_categorie_id' => ['required', 'integer', 'exists:sous_categories,id'],
        'marque_id' => ['nullable', 'integer', 'exists:marques,id'],
        'code_article' => ['required', 'string', 'max:50', 'unique:articles,code_article'],
        'nom' => ['nullable', 'string', 'max:150'],
        'name_ar' => ['nullable', 'string', 'max:150'],
        'name_fr' => ['nullable', 'string', 'max:150'],
        'description' => ['nullable', 'string'],
        'unite' => ['nullable', 'string', 'max:20'],
        'image' => ['required','image'],
        'actif' => ['nullable', 'boolean'],
        'prix_achat' => ['nullable', 'numeric', 'min:0'],
        'prix_vente' => ['nullable', 'numeric', 'min:0'],
        'prix_gros' => ['nullable', 'numeric', 'min:0'],
        'stock_initial' => ['nullable', 'numeric'],
        'seuil_min' => ['nullable', 'numeric', 'min:0'],
    ];

    protected array $updateRules = [
        'sous_categorie_id' => ['sometimes', 'required', 'integer', 'exists:sous_categories,id'],
        'marque_id' => ['nullable', 'integer', 'exists:marques,id'],
        'code_article' => ['sometimes', 'required', 'string', 'max:50'],
        'nom' => ['sometimes', 'required', 'string', 'max:150'],
        'name_ar' => ['nullable', 'string', 'max:150'],
        'name_fr' => ['nullable', 'string', 'max:150'],
        'description' => ['nullable', 'string'],
        'unite' => ['nullable', 'string', 'max:20', 'exists:unites,nom'],
        'image' => ['nullable', 'image'],
        'actif' => ['nullable', 'boolean'],
    ];

    public function store(Request $request)
    {
        $data = $request->validate($this->storeRules);

        /** @var Article $model */
        $model = new $this->modelClass();

        try {
            return \Illuminate\Support\Facades\DB::transaction(function () use ($request, $data, $model) {
                $imageFile = $request->file('image');
                unset($data['image']);

                $data['nom'] = (!empty($data['name_fr']) ? $data['name_fr'] : (!empty($data['name_ar']) ? $data['name_ar'] : 'Sans nom'));
                $model->fill($data);
                $model->save();

                $path = $imageFile->store('articles/' . $model->id, 'public');
                $model->image = Storage::url($path);
                $model->save();

                if ($request->has('prix_vente')) {
                    $model->prix()->create([
                        'prix_achat' => $request->input('prix_achat', 0),
                        'prix_vente' => $request->input('prix_vente', 0),
                        'prix_gros' => $request->input('prix_gros', $request->input('prix_vente', 0)),
                    ]);
                }

                if ($request->has('stock_initial')) {
                    $model->stock()->create([
                        'quantite' => $request->input('stock_initial', 0),
                        'seuil_min' => $request->input('seuil_min', 5),
                    ]);
                }

                $this->logAction('create', $model->getTable(), (int) $model->getKey(), $data);
                $model->load($this->with);
                return response()->json($model, 201);
            });
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
    }

    public function update(Request $request, string $id)
    {
        /** @var Article $model */
        $model = ($this->modelClass)::query()->findOrFail($id);

        $rules = $this->updateRules;
        $rules['code_article'] = [
            'sometimes',
            'required',
            'string',
            'max:50',
            Rule::unique('articles', 'code_article')->ignore($model->id),
        ];

        $data = $request->validate($rules);

        try {
            if ($request->hasFile('image')) {
                $this->deletePublicFileIfAny($model->image);
                $path = $request->file('image')->store('articles/' . $model->id, 'public');
                $data['image'] = Storage::url($path);
            } else {
                unset($data['image']);
            }

            if (!empty($data['name_fr']) || !empty($data['name_ar'])) {
                $data['nom'] = !empty($data['name_fr']) ? $data['name_fr'] : $data['name_ar'];
            }
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

        $model->load($this->with);
        return response()->json($model);
    }

    private function deletePublicFileIfAny(?string $url): void
    {
        if (!$url) return;
        if (!str_starts_with($url, '/storage/')) return;
        $path = ltrim(substr($url, strlen('/storage/')), '/');
        if ($path) {
            Storage::disk('public')->delete($path);
        }
    }
}
