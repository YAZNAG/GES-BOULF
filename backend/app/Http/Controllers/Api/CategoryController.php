<?php

namespace App\Http\Controllers\Api;

use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class CategoryController extends CrudController
{
    protected string $modelClass = Category::class;

    protected array $with = ['sousCategories'];

    protected array $storeRules = [
        'nom' => ['nullable', 'string', 'max:100'],
        'name_ar' => ['nullable', 'string', 'max:100'],
        'name_fr' => ['nullable', 'string', 'max:100'],
        'description' => ['nullable', 'string'],
        'famille_id' => ['nullable', 'exists:familles,id'],
        'image' => ['required', 'file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:10240'],
    ];

    protected array $updateRules = [
        'nom' => ['sometimes', 'nullable', 'string', 'max:100'],
        'name_ar' => ['nullable', 'string', 'max:100'],
        'name_fr' => ['nullable', 'string', 'max:100'],
        'description' => ['nullable', 'string'],
        'famille_id' => ['nullable', 'exists:familles,id'],
'image' => ['nullable', 'file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:10240'],
    ];

    public function index(Request $request)
    {
        $query = $this->modelClass::query()->with($this->with);

        if ($request->has('famille_id') && $request->famille_id) {
            $query->where('famille_id', $request->famille_id);
        }

        $perPage = (int) $request->query('per_page', 20);
        $perPage = max(1, min(1000, $perPage));

        return response()->json($query->paginate($perPage));
    }

    public function store(Request $request)
    {
        $data = $request->validate($this->storeRules);

        $data['nom'] = !empty($data['name_fr'])
            ? $data['name_fr']
            : (!empty($data['name_ar']) ? $data['name_ar'] : 'Sans nom');

        $imageFile = $request->file('image');
        unset($data['image']);

        /** @var Category $model */
        $model = new $this->modelClass();
        $model->fill($data);
        $model->save();

        $path = $imageFile->store('categories/' . $model->id, 'public');

        $model->image = Storage::url($path);
        $model->save();

        $this->logAction('create', $model->getTable(), (int) $model->getKey(), $data);

        $model->load($this->with);

        return response()->json($model, 201);
    }

    public function update(Request $request, string $id)
    {
        /** @var Category $model */
        $model = ($this->modelClass)::query()->findOrFail($id);

        $data = $request->validate($this->updateRules);

        if (!empty($data['name_fr']) || !empty($data['name_ar'])) {
            $data['nom'] = !empty($data['name_fr'])
                ? $data['name_fr']
                : $data['name_ar'];
        }

        if ($request->hasFile('image')) {
            $this->deletePublicFileIfAny($model->image);
            $path = $request->file('image')->store('categories/' . $model->id, 'public');
            $data['image'] = Storage::url($path);
        } else {
            unset($data['image']);
        }

        $model->fill($data);
        $model->save();

        $this->logAction('update', $model->getTable(), (int) $model->getKey(), $data);

        $model->load($this->with);

        return response()->json($model);
    }

    private function deletePublicFileIfAny(?string $url): void
    {
        if (!$url) {
            return;
        }

        if (!str_starts_with($url, '/storage/')) {
            return;
        }

        $path = ltrim(str_replace('/storage/', '', $url), '/');

        if ($path && Storage::disk('public')->exists($path)) {
            Storage::disk('public')->delete($path);
        }
    }
}