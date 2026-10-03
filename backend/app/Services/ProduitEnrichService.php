<?php

namespace App\Services;

use App\Models\SousCategorie;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Fiche produit automatique à partir d'un code-barres (EAN) :
 *  1. bases ouvertes Open Food Facts / Open Beauty Facts / Open Products Facts (nom, marque, contenance, photo) ;
 *  2. assistant IA facultatif (Claude, si ANTHROPIC_API_KEY est configurée) : nom arabe, nom français propre,
 *     sous-catégorie du catalogue. Sans clé, ces champs restent à saisir.
 */
class ProduitEnrichService
{
    private const SOURCES = [
        'Open Food Facts' => 'https://world.openfoodfacts.org',
        'Open Beauty Facts' => 'https://world.openbeautyfacts.org',
        'Open Products Facts' => 'https://world.openproductsfacts.org',
    ];

    private const FIELDS = 'product_name,product_name_fr,product_name_ar,generic_name_fr,brands,quantity,image_front_url,image_url,categories_tags';

    public function enrich(string $code): array
    {
        $fiche = [
            'code_article' => $code,
            'name_fr' => null,
            'name_ar' => null,
            'marque' => null,
            'contenance' => null,
            'image_url' => null,
            'sous_categorie_id' => null,
            'source' => null,
            'ia' => false,
        ];

        $off = $this->openFacts($code);
        if ($off) {
            $p = $off['product'];
            $nom = trim((string) ($p['product_name_fr'] ?? '') ?: (string) ($p['product_name'] ?? '') ?: (string) ($p['generic_name_fr'] ?? ''));
            $marque = trim(Str::before((string) ($p['brands'] ?? ''), ','));
            // « 400 g e » / « 400 g ℮ » : le signe e (estimé) n'a pas sa place dans le nom.
            $contenance = trim(preg_replace('/\s+[e℮]$/u', '', trim((string) ($p['quantity'] ?? ''))));
            if ($nom !== '' && $marque !== '' && ! Str::contains(Str::lower($nom), Str::lower($marque))) {
                $nom .= ' '.$marque;
            }
            if ($nom !== '' && $contenance !== '' && ! Str::contains(Str::lower($nom), Str::lower($contenance))) {
                $nom .= ' '.$contenance;
            }
            $fiche = array_merge($fiche, [
                'name_fr' => $nom !== '' ? Str::limit($nom, 150, '') : null,
                'name_ar' => trim((string) ($p['product_name_ar'] ?? '')) ?: null,
                'marque' => $marque ?: null,
                'contenance' => $contenance ?: null,
                'image_url' => $p['image_front_url'] ?? $p['image_url'] ?? null,
                'source' => $off['source'],
            ]);
            $tags = $p['categories_tags'] ?? [];
        }

        // Assistant IA : nom arabe, nom français propre, sous-catégorie.
        if (config('services.anthropic.key')) {
            $ia = $this->assistant($code, $fiche, $tags ?? []);
            if ($ia) {
                $fiche['name_fr'] = $fiche['name_fr'] ?: ($ia['name_fr'] ?? null);
                $fiche['name_ar'] = $fiche['name_ar'] ?: ($ia['name_ar'] ?? null);
                $fiche['marque'] = $fiche['marque'] ?: ($ia['marque'] ?? null);
                $fiche['sous_categorie_id'] = $ia['sous_categorie_id'] ?? null;
                $fiche['ia'] = true;
            }
        }

        // Sans IA (ou si elle hésite) : la sous-catégorie la plus fréquente des articles de la même marque.
        if (! $fiche['sous_categorie_id'] && $fiche['marque']) {
            $fiche['sous_categorie_id'] = \App\Models\Article::query()
                ->whereHas('marque', fn ($m) => $m->where('nom', $fiche['marque']))
                ->selectRaw('sous_categorie_id, count(*) as n')->groupBy('sous_categorie_id')->orderByDesc('n')
                ->value('sous_categorie_id');
        }

        $fiche['trouve'] = (bool) ($fiche['name_fr'] || $fiche['image_url']);

        return $fiche;
    }

    /** Première base ouverte qui connaît ce code. */
    private function openFacts(string $code): ?array
    {
        foreach (self::SOURCES as $source => $base) {
            try {
                $res = Http::withHeaders(['User-Agent' => 'Boulfrik/1.0 (contact@optizaworks.com)'])
                    ->timeout(8)
                    ->get("{$base}/api/v2/product/{$code}.json", ['fields' => self::FIELDS]);
                if ($res->ok() && (int) $res->json('status') === 1 && $res->json('product')) {
                    return ['source' => $source, 'product' => $res->json('product')];
                }
            } catch (\Throwable $e) {
                Log::info("Fiche produit {$code} : {$source} indisponible ({$e->getMessage()})");
            }
        }

        return null;
    }

    /** Claude : traduction arabe, nom français et choix de la sous-catégorie dans le catalogue existant. */
    private function assistant(string $code, array $fiche, array $tags): ?array
    {
        $sous = SousCategorie::query()->with('categorie:id,nom')->get(['id', 'nom', 'categorie_id'])
            ->map(fn ($s) => "{$s->id}: ".($s->categorie?->nom ? "{$s->categorie->nom} > " : '').$s->nom)
            ->implode("\n");

        $connu = json_encode(array_filter([
            'nom' => $fiche['name_fr'], 'marque' => $fiche['marque'], 'contenance' => $fiche['contenance'],
            'categories_open_food_facts' => array_slice($tags, 0, 12),
        ]), JSON_UNESCAPED_UNICODE);

        $prompt = <<<TXT
Tu prépares la fiche d'un produit vendu dans un supermarché au Maroc.
Code-barres EAN : {$code}
Informations connues (peuvent être vides) : {$connu}

Sous-catégories du catalogue (id: catégorie > sous-catégorie) :
{$sous}

Réponds UNIQUEMENT par un objet JSON :
{"name_fr": "nom commercial court en français avec marque et contenance", "name_ar": "le même nom en arabe (écriture arabe, marque translittérée)", "marque": "marque ou null", "sous_categorie_id": id le plus adapté ou null}
Si les informations connues sont vides et que tu ne reconnais pas ce code avec certitude, mets null pour name_fr, marque et sous_categorie_id : n'invente pas de produit.
TXT;

        try {
            $res = Http::withHeaders([
                'x-api-key' => config('services.anthropic.key'),
                'anthropic-version' => '2023-06-01',
            ])->timeout(25)->post('https://api.anthropic.com/v1/messages', [
                'model' => config('services.anthropic.model'),
                'max_tokens' => 400,
                'messages' => [['role' => 'user', 'content' => $prompt]],
            ]);
            if (! $res->ok()) {
                Log::warning('Assistant IA fiche produit : HTTP '.$res->status());

                return null;
            }
            $texte = collect($res->json('content', []))->where('type', 'text')->pluck('text')->implode('');
            if (! preg_match('/\{.*\}/s', $texte, $m)) {
                return null;
            }
            $json = json_decode($m[0], true);
            if (! is_array($json)) {
                return null;
            }
            $id = isset($json['sous_categorie_id']) && is_numeric($json['sous_categorie_id']) ? (int) $json['sous_categorie_id'] : null;

            return [
                'name_fr' => isset($json['name_fr']) ? Str::limit(trim((string) $json['name_fr']), 150, '') ?: null : null,
                'name_ar' => isset($json['name_ar']) ? Str::limit(trim((string) $json['name_ar']), 150, '') ?: null : null,
                'marque' => isset($json['marque']) ? trim((string) $json['marque']) ?: null : null,
                'sous_categorie_id' => $id && SousCategorie::query()->whereKey($id)->exists() ? $id : null,
            ];
        } catch (\Throwable $e) {
            Log::warning('Assistant IA fiche produit indisponible : '.$e->getMessage());

            return null;
        }
    }
}
