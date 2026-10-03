<?php

namespace App\Http\Controllers;

use App\Models\SubCategory;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class SubCategoryController extends Controller
{
    protected string $modelClass = SubCategory::class;

    protected array $with = ['sousCategorie', 'articles'];

    protected array $storeRules = [
        'sous_categorie_id' => ['required', 'exists:sous_categories,id'],
        'nom' => ['nullable', 'string', 'max:100'],
        'name_ar' => ['nullable', 'string', 'max:100'],
        'name_fr' => ['nullable', 'string', 'max:100'],
        'description' => ['nullable', 'string'],
        'image' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096'],
    ];

    protected array $updateRules = [
        'sous_categorie_id' => ['sometimes', 'required', 'exists:sous_categories,id'],
        'nom' => ['sometimes', 'nullable', 'string', 'max:100'],
        'name_ar' => ['nullable', 'string', 'max:100'],
        'name_fr' => ['nullable', 'string', 'max:100'],
        'description' => ['nullable', 'string'],
        'image' => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:4096'],
    ];

    public function index(Request $request)
    {
        $query = $this->modelClass::query()->with($this->with);

        if ($request->has('sous_categorie_id')) {
            $query->where('sous_categorie_id', $request->sous_categorie_id);
        }

        $perPage = $request->get('per_page', 15);
        $items = $query->paginate($perPage);

        return response()->json($items);
    }

    public function store(Request $request)
    {
        $data = $request->validate($this->storeRules);

        $data['nom'] = !empty($data['name_fr'])
            ? $data['name_fr']
            : (!empty($data['name_ar']) ? $data['name_ar'] : 'Sans nom');

        $imageFile = $request->file('image');
        unset($data['image']);

        /** @var SubCategory $model */
        $model = new $this->modelClass();
        $model->fill($data);
        $model->save();

        $path = $imageFile->store('image/sous_categorie/' . $model->id, 'public');

        $model->image = Storage::url($path);
        $model->save();

        $this->logAction('create', $model->getTable(), (int) $model->getKey(), $data);

        $model->load($this->with);

        return response()->json($model, 201);
    }

    public function show(string $id)
    {
        $model = $this->modelClass::query()->with($this->with)->findOrFail($id);

        return response()->json($model);
    }

    public function update(Request $request, string $id)
    {
        /** @var SubCategory $model */
        $model = $this->modelClass::query()->findOrFail($id);

        $data = $request->validate($this->updateRules);

        if (!empty($data['name_fr']) || !empty($data['name_ar'])) {
            $data['nom'] = !empty($data['name_fr'])
                ? $data['name_fr']
                : $data['name_ar'];
        }

        if ($request->hasFile('image')) {
            $this->deletePublicFileIfAny($model->image);

            $path = $request->file('image')->store('image/sous_categorie/' . $model->id, 'public');

            $data['image'] = Storage::url($path);
        }

        $model->fill($data);
        $model->save();

        $this->logAction('update', $model->getTable(), (int) $model->getKey(), $data);

        $model->load($this->with);

        return response()->json($model);
    }

    public function destroy(string $id)
    {
        $model = $this->modelClass::query()->findOrFail($id);

        $this->logAction('delete', $model->getTable(), (int) $model->getKey(), $model->toArray());

        $this->deletePublicFileIfAny($model->image);

        $model->delete();

        return response()->json(['message' => 'Deleted']);
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

        if ($path) {
            Storage::disk('public')->delete($path);
        }
    }

    private function logAction(string $action, string $table, int $recordId, array $data): void
    {
        // Log action if needed
    }
}
