<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CategorieCharge;
use App\Models\Charge;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

/** Charges (dépenses) du magasin et leurs catégories. */
class ChargeController extends Controller
{
    /** Liste : du, au (par défaut le mois en cours), categorie_id, q ; + total et répartition par catégorie. */
    public function index(Request $request)
    {
        $du = $request->query('du', now()->startOfMonth()->toDateString());
        $au = $request->query('au', now()->endOfMonth()->toDateString());
        $base = Charge::query()->whereBetween('date_charge', [$du, $au]);
        if ($request->filled('categorie_id')) {
            $base->where('categorie_charge_id', $request->query('categorie_id'));
        }
        if ($s = trim((string) $request->query('q', ''))) {
            $base->where(fn ($w) => $w->where('libelle', 'like', "%{$s}%")->orWhere('beneficiaire', 'like', "%{$s}%")->orWhere('reference', 'like', "%{$s}%"));
        }

        $page = (clone $base)->with(['categorie', 'utilisateur:id,nom'])->orderByDesc('date_charge')->orderByDesc('id')
            ->paginate(max(1, min(100, (int) $request->query('per_page', 30))))->toArray();
        $page['periode'] = ['du' => $du, 'au' => $au];
        $page['montant_total'] = round((float) (clone $base)->sum('montant'), 2);
        $page['par_categorie'] = (clone $base)->reorder()
            ->join('categories_charges as cc', 'cc.id', '=', 'charges.categorie_charge_id')
            ->groupBy('cc.id', 'cc.nom', 'cc.couleur', 'cc.icone')
            ->orderByDesc('montant')
            ->get(['cc.id', 'cc.nom', 'cc.couleur', 'cc.icone', \DB::raw('SUM(charges.montant) as montant'), \DB::raw('COUNT(*) as nombre')]);

        return response()->json($page);
    }

    public function show(int $id)
    {
        return response()->json(Charge::query()->with(['categorie', 'utilisateur:id,nom'])->findOrFail($id));
    }

    public function store(Request $request)
    {
        $data = $request->validate($this->rules());
        unset($data['piece']);
        $charge = Charge::query()->create($data + ['utilisateur_id' => $request->user()?->id]);
        $this->piece($request, $charge);

        return response()->json($charge->load('categorie'), 201);
    }

    public function update(Request $request, int $id)
    {
        $charge = Charge::query()->findOrFail($id);
        $data = $request->validate($this->rules());
        unset($data['piece']);
        $charge->update($data);
        $this->piece($request, $charge);

        return response()->json($charge->load('categorie'));
    }

    public function destroy(int $id)
    {
        $charge = Charge::query()->findOrFail($id);
        if ($charge->piece && str_starts_with($charge->piece, '/storage/')) {
            Storage::disk('public')->delete(substr($charge->piece, strlen('/storage/')));
        }
        $charge->delete();

        return response()->json(['deleted' => true]);
    }

    public function categories()
    {
        return response()->json(CategorieCharge::query()->where('actif', true)->orderBy('nom')->get());
    }

    public function ajouterCategorie(Request $request)
    {
        $data = $request->validate([
            'nom' => ['required', 'string', 'max:80', 'unique:categories_charges,nom'],
            'couleur' => ['nullable', 'string', 'max:9'],
            'icone' => ['nullable', 'string', 'max:40'],
        ]);

        return response()->json(CategorieCharge::query()->create($data + ['actif' => true]), 201);
    }

    private function rules(): array
    {
        return [
            'categorie_charge_id' => ['required', 'integer', 'exists:categories_charges,id'],
            'libelle' => ['required', 'string', 'max:150'],
            'montant' => ['required', 'numeric', 'gt:0'],
            'date_charge' => ['required', 'date'],
            'mode_paiement' => ['nullable', 'string', 'max:30'],
            'reference' => ['nullable', 'string', 'max:60'],
            'beneficiaire' => ['nullable', 'string', 'max:120'],
            'note' => ['nullable', 'string', 'max:2000'],
            'piece' => ['nullable', 'image', 'max:10240'],
        ];
    }

    /** Photo du justificatif (facture, reçu). */
    private function piece(Request $request, Charge $charge): void
    {
        if (! $request->hasFile('piece')) {
            return;
        }
        if ($charge->piece && str_starts_with($charge->piece, '/storage/')) {
            Storage::disk('public')->delete(substr($charge->piece, strlen('/storage/')));
        }
        $path = $request->file('piece')->store('charges/'.$charge->id, 'public');
        $charge->update(['piece' => Storage::url($path)]);
    }
}
