<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/**
 * Photo d'un élément : remplacer (POST, champ « image ») ou supprimer (DELETE).
 * Types : articles, familles, categories, sous_categories, marques, charges (justificatif).
 */
class ImageController extends Controller
{
    /** type => [modèle, colonne, dossier de stockage] */
    private const TYPES = [
        'articles' => [\App\Models\Article::class, 'image', 'articles'],
        'familles' => [\App\Models\Famille::class, 'image', 'familles'],
        'categories' => [\App\Models\Category::class, 'image', 'categories'],
        'sous_categories' => [\App\Models\SousCategorie::class, 'image', 'sous_categories'],
        'marques' => [\App\Models\Marque::class, 'image', 'marques'],
        'charges' => [\App\Models\Charge::class, 'piece', 'charges'],
    ];

    public function remplacer(Request $request, string $type, int $id)
    {
        [$model, $col, $folder] = $this->type($type);
        $request->validate(['image' => ['required', 'image', 'max:10240']]);
        $item = $model::query()->findOrFail($id);
        $this->effacer($item->{$col});
        $path = $request->file('image')->store("{$folder}/{$id}", 'public');
        $item->update([$col => Storage::url($path)]);

        return response()->json([$col => $item->{$col}]);
    }

    public function supprimer(string $type, int $id)
    {
        [$model, $col] = $this->type($type);
        $item = $model::query()->findOrFail($id);
        $this->effacer($item->{$col});
        $item->update([$col => null]);

        return response()->json([$col => null]);
    }

    private function type(string $type): array
    {
        abort_unless(isset(self::TYPES[$type]), 404, 'Type inconnu.');

        return self::TYPES[$type];
    }

    /** Supprime le fichier s'il est stocké chez nous. */
    private function effacer(?string $url): void
    {
        if ($url && str_starts_with($url, '/storage/')) {
            Storage::disk('public')->delete(substr($url, strlen('/storage/')));
        }
    }
}
