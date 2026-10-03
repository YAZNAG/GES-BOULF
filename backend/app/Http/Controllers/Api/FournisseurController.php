<?php

namespace App\Http\Controllers\Api;

use App\Models\Fournisseur;
use Illuminate\Http\Request;

class FournisseurController extends CrudController
{
    protected string $modelClass = Fournisseur::class;

    protected array $storeRules = [
        'code' => ['nullable', 'string', 'max:30'],
        'nom' => ['required', 'string', 'max:150'],
        'contact' => ['nullable', 'string', 'max:120'],
        'telephone' => ['nullable', 'string', 'max:20'],
        'email' => ['nullable', 'email', 'max:100'],
        'adresse' => ['nullable', 'string'],
        'ville' => ['nullable', 'string', 'max:80'],
        'ice' => ['nullable', 'string', 'max:20'],
        'rc' => ['nullable', 'string', 'max:30'],
        'plafond_credit' => ['nullable', 'numeric', 'min:0'],
        'delai_paiement' => ['nullable', 'integer', 'min:0', 'max:365'],
        'note' => ['nullable', 'string'],
        'actif' => ['nullable', 'boolean'],
    ];

    protected array $updateRules = [
        'code' => ['nullable', 'string', 'max:30'],
        'nom' => ['sometimes', 'required', 'string', 'max:150'],
        'contact' => ['nullable', 'string', 'max:120'],
        'telephone' => ['nullable', 'string', 'max:20'],
        'email' => ['nullable', 'email', 'max:100'],
        'adresse' => ['nullable', 'string'],
        'ville' => ['nullable', 'string', 'max:80'],
        'ice' => ['nullable', 'string', 'max:20'],
        'rc' => ['nullable', 'string', 'max:30'],
        'plafond_credit' => ['nullable', 'numeric', 'min:0'],
        'delai_paiement' => ['nullable', 'integer', 'min:0', 'max:365'],
        'note' => ['nullable', 'string'],
        'actif' => ['nullable', 'boolean'],
    ];

    /**
     * Liste avec recherche (q), filtre crédit (avec_credit=1), cumuls d'achats et statistiques.
     * Le solde (crédit fournisseur) n'est jamais modifiable directement : il bouge avec les réceptions et règlements.
     */
    public function index(Request $request)
    {
        $query = Fournisseur::query()
            ->withCount(['commandes', 'receptions'])
            ->withSum('receptions as total_achats', 'total')
            ->withMax('receptions as derniere_reception', 'date_reception')
            ->orderBy('nom');

        if ($q = trim((string) $request->query('q', ''))) {
            $query->where(fn ($w) => $w->where('nom', 'like', "%{$q}%")->orWhere('code', 'like', "%{$q}%")
                ->orWhere('telephone', 'like', "%{$q}%")->orWhere('ville', 'like', "%{$q}%")->orWhere('ice', 'like', "%{$q}%"));
        }
        if ($request->boolean('avec_credit')) {
            $query->where('solde', '>', 0);
        }
        if ($request->filled('actif')) {
            $query->where('actif', $request->boolean('actif'));
        }

        $page = $query->paginate(max(1, min(1000, (int) $request->query('per_page', 50))))->toArray();
        $page['stats'] = [
            'total' => Fournisseur::query()->count(),
            'actifs' => Fournisseur::query()->where('actif', true)->count(),
            'credit_total' => (float) Fournisseur::query()->sum('solde'),
            'avec_credit' => Fournisseur::query()->where('solde', '>', 0)->count(),
            'depassement' => Fournisseur::query()->whereNotNull('plafond_credit')->whereColumn('solde', '>', 'plafond_credit')->count(),
        ];

        return response()->json($page);
    }

    public function show(string $id)
    {
        return response()->json(Fournisseur::query()
            ->withCount(['commandes', 'receptions'])
            ->withSum('receptions as total_achats', 'total')
            ->withSum('paiements as total_paye', 'montant')
            ->findOrFail($id));
    }
}
