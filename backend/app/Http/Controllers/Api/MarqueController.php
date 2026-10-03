<?php

namespace App\Http\Controllers\Api;

use App\Models\Marque;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class MarqueController extends CrudController
{
    protected string $modelClass = Marque::class;

    protected array $searchable = ['nom', 'description'];

    protected array $storeRules = [
        'nom' => 'required|string|max:100',
        'image' => 'nullable|image|max:2048',
        'description' => 'nullable|string',
    ];

    protected array $updateRules = [
        'nom' => 'required|string|max:100',
        'image' => 'nullable|image|max:2048',
        'description' => 'nullable|string',
    ];

    public function store(Request $request)
    {
        $data = $request->validate($this->storeRules);

        if ($request->hasFile('image')) {
            $data['image'] = $request->file('image')->store('marques', 'public');
        }

        $model = new $this->modelClass($data);
        $model->save();

        $this->logAction('create', $model->getTable(), (int) $model->getKey(), $data);

        return response()->json($model, 201);
    }

    public function update(Request $request, string $id)
    {
        $model = ($this->modelClass)::findOrFail($id);
        
        // Handle multipart/form-data for PUT (Laravel quirk: use POST with _method=PUT)
        $data = $request->validate($this->updateRules);

        if ($request->hasFile('image')) {
            if ($model->image) {
                Storage::disk('public')->delete($model->image);
            }
            $data['image'] = $request->file('image')->store('marques', 'public');
        }

        $model->fill($data);
        $model->save();

        $this->logAction('update', $model->getTable(), (int) $model->getKey(), $data);

        return response()->json($model);
    }

    public function destroy(string $id)
    {
        $marque = Marque::findOrFail($id);
        if ($marque->articles()->exists()) {
            return response()->json([
                'message' => "Impossible de supprimer cette marque : des articles y sont rattachés.",
                'code' => 'FK_CONSTRAINT'
            ], 409);
        }
        return parent::destroy($id);
    }
}
