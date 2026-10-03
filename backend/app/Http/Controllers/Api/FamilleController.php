<?php

namespace App\Http\Controllers\Api;

use App\Models\Famille;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class FamilleController extends CrudController
{
    protected string $modelClass = Famille::class;

    protected array $storeRules = [
        'nom_ar' => ['nullable', 'string', 'max:255'],
        'nom_fr' => ['nullable', 'string', 'max:255'],
'image' => ['nullable', 'file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:10240'],
    ];

    protected array $updateRules = [
        'nom_ar' => ['nullable', 'string', 'max:255'],
        'nom_fr' => ['nullable', 'string', 'max:255'],
        'image'  => ['nullable', 'file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:10240'],
    ];

    public function store(Request $request)
    {
        $data = $request->validate($this->storeRules);

        $imageFile = $request->file('image');
        unset($data['image']);

        /** @var Famille $model */
        $model = new $this->modelClass();
        $model->fill($data);
        $model->save();

        if ($imageFile) {
            $path = $imageFile->store('familles/' . $model->id, 'public');
            $model->image = Storage::url($path);
            $model->save();
        }

        $this->logAction('create', $model->getTable(), (int) $model->getKey(), $data);

        return response()->json($model, 201);
    }

    public function update(Request $request, string $id)
    {
        /** @var Famille $model */
        $model = ($this->modelClass)::query()->findOrFail($id);

        $data = $request->validate($this->updateRules);

        if ($request->hasFile('image')) {
            $this->deletePublicFileIfAny($model->image);
            $path = $request->file('image')->store('familles/' . $model->id, 'public');
            $data['image'] = Storage::url($path);
        } else {
            unset($data['image']);
        }

        $model->fill($data);
        $model->save();

        $this->logAction('update', $model->getTable(), (int) $model->getKey(), $data);

        return response()->json($model);
    }

    private function deletePublicFileIfAny(?string $url): void
    {
        if (!$url) return;
        if (!str_starts_with($url, '/storage/')) return;
        $path = ltrim(substr($url, strlen('/storage/')), '/');
        if ($path && Storage::disk('public')->exists($path)) {
            Storage::disk('public')->delete($path);
        }
    }
}
