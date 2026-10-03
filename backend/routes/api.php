<?php

use App\Http\Controllers\Api\AchatController;
use App\Http\Controllers\Api\ArticleController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\ClientController;
use App\Http\Controllers\Api\CommandeVenteController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\FournisseurController;
use App\Http\Controllers\Api\LigneCommandeVenteController;
use App\Http\Controllers\Api\MouvementStockController;
use App\Http\Controllers\Api\PackController;
use App\Http\Controllers\Api\PrixArticleController;
use App\Http\Controllers\Api\PromotionController;
use App\Http\Controllers\Api\RoleController;
use App\Http\Controllers\Api\SousCategorieController;
use App\Http\Controllers\Api\StockController;
use App\Http\Controllers\Api\UtilisateurController;
use App\Http\Controllers\Api\VenteController;
use App\Http\Controllers\Api\POSController;
use App\Http\Controllers\Api\FactureController;
use App\Http\Controllers\Api\PaiementController;
use App\Http\Controllers\Api\UniteController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\RetourController;
use App\Http\Controllers\Api\MarqueController;
use App\Http\Controllers\Api\ModePaiementController;
use App\Http\Controllers\Api\FamilleController;
use Illuminate\Support\Facades\Route;

Route::get('/health', fn() => response()->json(['ok' => true]));



Route::post('retours', [RetourController::class, 'store']);

Route::middleware(['auth:sanctum', 'permission:systeme.stats'])->get('admin/reports/sales', [ReportController::class, 'salesReport']);

Route::prefix('auth')->group(function () {
    Route::post('login', [AuthController::class, 'login']);
    Route::middleware('auth:sanctum')->get('me', [AuthController::class, 'me']);
    Route::middleware('auth:sanctum')->post('logout', [AuthController::class, 'logout']);
});

Route::middleware(['auth:sanctum', 'role:admin'])->get('admin/dashboard', fn() => response()->json([
    'message' => 'hi admin',
]));

Route::middleware(['auth:sanctum', 'permission:systeme.stats'])->get('admin/dashboard/stats', [DashboardController::class, 'stats']);
Route::middleware(['auth:sanctum', 'permission:systeme.stats'])->get('admin/notifications', [NotificationController::class, 'index']);

Route::middleware(['auth:sanctum', 'permission:utilisateurs.manage|systeme.settings'])->group(function () {
    Route::get('roles', [RoleController::class, 'index']);
    Route::get('roles/{role}', [RoleController::class, 'show']);
});
Route::middleware(['auth:sanctum', 'permission:systeme.settings'])->group(function () {
    Route::post('roles', [RoleController::class, 'store']);
    Route::put('roles/{role}', [RoleController::class, 'update']);
    Route::patch('roles/{role}', [RoleController::class, 'update']);
    Route::delete('roles/{role}', [RoleController::class, 'destroy']);
});

Route::middleware(['auth:sanctum', 'permission:utilisateurs.view|systeme.settings'])->group(function () {
    Route::get('utilisateurs', [UtilisateurController::class, 'index']);
    Route::get('utilisateurs/{utilisateur}', [UtilisateurController::class, 'show']);
});
Route::middleware(['auth:sanctum', 'permission:utilisateurs.manage|systeme.settings'])->group(function () {
    Route::post('utilisateurs', [UtilisateurController::class, 'store']);
    Route::put('utilisateurs/{utilisateur}', [UtilisateurController::class, 'update']);
    Route::patch('utilisateurs/{utilisateur}', [UtilisateurController::class, 'update']);
    Route::delete('utilisateurs/{utilisateur}', [UtilisateurController::class, 'destroy']);
});

Route::apiResource('categories', CategoryController::class);
Route::apiResource('sous_categories', SousCategorieController::class);
Route::apiResource('familles', FamilleController::class);
Route::get('articles/lookup', [ArticleController::class, 'lookup']);
Route::middleware('auth:sanctum')->get('articles/fiche', [ArticleController::class, 'fiche']);
Route::middleware('auth:sanctum')->post('articles/rapide', [ArticleController::class, 'rapide']);
Route::apiResource('articles', ArticleController::class);
Route::apiResource('prix_articles', PrixArticleController::class);
Route::apiResource('unites', UniteController::class);
Route::apiResource('marques', MarqueController::class);
Route::apiResource('mode_paiements', ModePaiementController::class);

Route::middleware('auth:sanctum')->post('stock/ajuster', [StockController::class, 'ajuster']);
Route::apiResource('stock', StockController::class);
Route::apiResource('mouvements_stock', MouvementStockController::class)->only(['index', 'show', 'store']);

Route::apiResource('fournisseurs', FournisseurController::class);
Route::get('clients/{id}/history', [ClientController::class, 'history']);
Route::apiResource('clients', ClientController::class);
Route::middleware(['auth:sanctum', 'permission:commandes.view'])->group(function () {
    Route::get('commandes_vente', [CommandeVenteController::class, 'index']);
    Route::get('commandes_vente/{commande_vente}', [CommandeVenteController::class, 'show']);
});
Route::middleware(['auth:sanctum', 'permission:commandes.edit'])->group(function () {
    Route::put('commandes_vente/{commande_vente}', [CommandeVenteController::class, 'update']);
    Route::patch('commandes_vente/{commande_vente}', [CommandeVenteController::class, 'update']);
    Route::post('commandes_vente/{id}/confirmer', [CommandeVenteController::class, 'confirmer']);
    Route::post('commandes_vente/{id}/payer', [CommandeVenteController::class, 'payer']);
});
Route::middleware(['auth:sanctum', 'permission:commandes.cancel'])->delete('commandes_vente/{commande_vente}', [CommandeVenteController::class, 'destroy']);
Route::apiResource('lignes_commande_vente', LigneCommandeVenteController::class);
Route::apiResource('ventes', VenteController::class)->only(['index', 'show']);
Route::middleware('auth:sanctum')->post('pos/sale', [POSController::class, 'store']);
Route::apiResource('factures', FactureController::class);
Route::apiResource('paiements', PaiementController::class);

Route::apiResource('promotions', PromotionController::class);

Route::middleware(['auth:sanctum', 'permission:packs.view|systeme.settings'])->group(function () {
    Route::get('packs', [PackController::class, 'index']);
    Route::get('packs/{pack}', [PackController::class, 'show']);
});
Route::middleware(['auth:sanctum', 'permission:packs.manage|systeme.settings'])->group(function () {
    Route::post('packs', [PackController::class, 'store']);
    Route::put('packs/{pack}', [PackController::class, 'update']);
    Route::patch('packs/{pack}', [PackController::class, 'update']);
    Route::delete('packs/{pack}', [PackController::class, 'destroy']);
});

// ── Achats : bons de commande, réceptions (entrées de stock), règlements fournisseurs ──
Route::middleware('auth:sanctum')->prefix('achats')->group(function () {
    Route::get('commandes', [AchatController::class, 'commandes']);
    Route::post('commandes', [AchatController::class, 'enregistrerCommande']);
    Route::get('commandes/{id}', [AchatController::class, 'commande'])->whereNumber('id');
    Route::put('commandes/{id}', [AchatController::class, 'enregistrerCommande'])->whereNumber('id');
    Route::post('commandes/{id}/statut', [AchatController::class, 'statutCommande'])->whereNumber('id');
    Route::delete('commandes/{id}', [AchatController::class, 'supprimerCommande'])->whereNumber('id');

    Route::get('receptions', [AchatController::class, 'receptions']);
    Route::post('receptions', [AchatController::class, 'receptionner']);
    Route::get('receptions/{id}', [AchatController::class, 'reception'])->whereNumber('id');

    Route::get('paiements', [AchatController::class, 'paiements']);
    Route::post('paiements', [AchatController::class, 'payer']);
    Route::get('fournisseurs/{id}/releve', [AchatController::class, 'releve'])->whereNumber('id');
});

// ── Tarifs de vente : tableau des prix, modification en ligne et actions groupées ──
Route::middleware('auth:sanctum')->prefix('tarifs')->group(function () {
    Route::get('/', [\App\Http\Controllers\Api\TarifController::class, 'index']);
    Route::get('export', [\App\Http\Controllers\Api\TarifController::class, 'export']);
    Route::post('bulk', [\App\Http\Controllers\Api\TarifController::class, 'bulk']);
    Route::put('{articleId}', [\App\Http\Controllers\Api\TarifController::class, 'update'])->whereNumber('articleId');
});

// ── Application mobile (et site) ──
Route::get('app/version', [\App\Http\Controllers\Api\MobileController::class, 'version']);
Route::middleware('auth:sanctum')->prefix('m')->group(function () {
    Route::get('dashboard', [\App\Http\Controllers\Api\MobileController::class, 'dashboard']);
    Route::get('ventes', [\App\Http\Controllers\Api\MobileController::class, 'ventes']);
    Route::get('ventes/{id}', [\App\Http\Controllers\Api\MobileController::class, 'vente'])->whereNumber('id');
    Route::get('clients', [\App\Http\Controllers\Api\MobileController::class, 'clients']);
    Route::get('mouvements', [\App\Http\Controllers\Api\MobileController::class, 'mouvements']);
});

// ── Inventaires (comptage physique) ──
Route::middleware('auth:sanctum')->prefix('inventaires')->group(function () {
    Route::get('/', [\App\Http\Controllers\Api\InventaireController::class, 'index']);
    Route::post('/', [\App\Http\Controllers\Api\InventaireController::class, 'store']);
    Route::get('{id}', [\App\Http\Controllers\Api\InventaireController::class, 'show'])->whereNumber('id');
    Route::post('{id}/compter', [\App\Http\Controllers\Api\InventaireController::class, 'compter'])->whereNumber('id');
    Route::delete('{id}/lignes/{ligne}', [\App\Http\Controllers\Api\InventaireController::class, 'retirerLigne'])->whereNumber(['id', 'ligne']);
    Route::post('{id}/valider', [\App\Http\Controllers\Api\InventaireController::class, 'valider'])->whereNumber('id');
    Route::post('{id}/annuler', [\App\Http\Controllers\Api\InventaireController::class, 'annuler'])->whereNumber('id');
});

// ── Charges (dépenses du magasin) ──
Route::middleware('auth:sanctum')->group(function () {
    Route::get('categories_charges', [\App\Http\Controllers\Api\ChargeController::class, 'categories']);
    Route::post('categories_charges', [\App\Http\Controllers\Api\ChargeController::class, 'ajouterCategorie']);
    Route::get('charges', [\App\Http\Controllers\Api\ChargeController::class, 'index']);
    Route::post('charges', [\App\Http\Controllers\Api\ChargeController::class, 'store']);
    Route::get('charges/{id}', [\App\Http\Controllers\Api\ChargeController::class, 'show'])->whereNumber('id');
    Route::put('charges/{id}', [\App\Http\Controllers\Api\ChargeController::class, 'update'])->whereNumber('id');
    Route::delete('charges/{id}', [\App\Http\Controllers\Api\ChargeController::class, 'destroy'])->whereNumber('id');
});
