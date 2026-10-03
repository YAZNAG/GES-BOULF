<?php

namespace App\Http\Controllers\Api;

use App\Models\SousCategorie;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class SousCategorieController extends CrudController
{
    protected string $modelClass = SousCategorie::class;

    protected array $with = ['categorie'];

    protected array $storeRules = [
        'categorie_id' => ['required', 'integer', 'exists:categories,id'],
        'nom' => ['nullable', 'string', 'max:100'],
        'name_ar' => ['nullable', 'string', 'max:100'],
        'name_fr' => ['nullable', 'string', 'max:100'],
        'description' => ['nullable', 'string'],
        'image' => ['required', 'image'],
    ];

    protected array $updateRules = [
        'categorie_id' => ['sometimes', 'required', 'integer', 'exists:categories,id'],
        'nom' => ['sometimes', 'required', 'string', 'max:100'],
        'name_ar' => ['nullable', 'string', 'max:100'],
        'name_fr' => ['nullable', 'string', 'max:100'],
        'description' => ['nullable', 'string'],
        'image' => ['nullable', 'image'],
    ];

    public function store(Request $request)
    {
        $data = $request->validate($this->storeRules);

        $imageFile = $request->file('image');
        unset($data['image']);

        /** @var SousCategorie $model */
        $model = new $this->modelClass();
        $data['nom'] = (!empty($data['name_fr']) ? $data['name_fr'] : (!empty($data['name_ar']) ? $data['name_ar'] : 'Sans nom'));
        $model->fill($data);
        $model->save();

        $path = $imageFile->store('sous_categories/' . $model->id, 'public');
        $model->image = Storage::url($path);
        $model->save();

        $this->logAction('create', $model->getTable(), (int) $model->getKey(), $data);
        $model->load($this->with);

        return response()->json($model, 201);
    }

    public function update(Request $request, string $id)
    {
        /** @var SousCategorie $model */
        $model = ($this->modelClass)::query()->findOrFail($id);

        $data = $request->validate($this->updateRules);

        if ($request->hasFile('image')) {
            $this->deletePublicFileIfAny($model->image);
            $path = $request->file('image')->store('sous_categories/' . $model->id, 'public');
            $data['image'] = Storage::url($path);
        } else {
            unset($data['image']);
        }

        if (!empty($data['name_fr']) || !empty($data['name_ar'])) {
            $data['nom'] = !empty($data['name_fr']) ? $data['name_fr'] : $data['name_ar'];
        }
        $model->fill($data);
        $model->save();

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
