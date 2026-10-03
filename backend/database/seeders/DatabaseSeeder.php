<?php

namespace Database\Seeders;

use App\Models\Article;
use App\Models\Category;
use App\Models\Client;
use App\Models\CommandeVente;
use App\Models\Fournisseur;
use App\Models\HistoriqueAction;
use App\Models\LigneCommandeVente;
use App\Models\MouvementStock;
use App\Models\PrixArticle;
use App\Models\Marque;
use App\Models\Promotion;
use App\Models\Role;
use App\Models\Sortie;
use App\Models\SousCategorie;
use App\Models\Stock;
use App\Models\User;
use App\Models\Utilisateur;
use App\Models\Vente;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    public function run(): void
    {
        $now = now();

        DB::table('roles')->upsert(
            [
                ['nom' => 'admin',      'description' => null, 'created_at' => $now, 'updated_at' => $now],
                ['nom' => 'vendeur',    'description' => null, 'created_at' => $now, 'updated_at' => $now],
                ['nom' => 'magasinier', 'description' => null, 'created_at' => $now, 'updated_at' => $now],
                ['nom' => 'agent',      'description' => null, 'created_at' => $now, 'updated_at' => $now],
                ['nom' => 'livreur',    'description' => null, 'created_at' => $now, 'updated_at' => $now],
            ],
            ['nom'],
            ['updated_at']
        );

        $adminRoleId     = DB::table('roles')->where('nom', 'admin')->value('id');
        $vendeurRoleId   = DB::table('roles')->where('nom', 'vendeur')->value('id');
        $magasinierRoleId = DB::table('roles')->where('nom', 'magasinier')->value('id');
        $agentRoleId     = DB::table('roles')->where('nom', 'agent')->value('id');
        $livreurRoleId   = DB::table('roles')->where('nom', 'livreur')->value('id');

        $admin = User::query()->updateOrCreate(
            ['email' => 'admin@elherii.ma'],
            [
                'role_id'     => $adminRoleId,
                'nom'         => 'El Herri',
                'prenom'      => 'Admin',
                'mot_de_passe' => Hash::make('password'),
                'actif'       => true,
            ]
        );

        $vendeur = User::query()->updateOrCreate(
            ['email' => 'vendeur@elherii.ma'],
            [
                'role_id'     => $vendeurRoleId,
                'nom'         => 'Benali',
                'prenom'      => 'Youssef',
                'mot_de_passe' => Hash::make('password'),
                'actif'       => true,
            ]
        );

        $magasinier = User::query()->updateOrCreate(
            ['email' => 'magasinier@elherii.ma'],
            [
                'role_id'     => $magasinierRoleId,
                'nom'         => 'Chakir',
                'prenom'      => 'Hamid',
                'mot_de_passe' => Hash::make('password'),
                'actif'       => true,
            ]
        );

        User::query()->updateOrCreate(
            ['email' => 'agent@elherii.ma'],
            [
                'role_id'     => $agentRoleId,
                'nom'         => 'Idrissi',
                'prenom'      => 'Salma',
                'mot_de_passe' => Hash::make('password'),
                'actif'       => true,
            ]
        );

        User::query()->updateOrCreate(
            ['email' => 'livreur@elherii.ma'],
            [
                'role_id'     => $livreurRoleId,
                'nom'         => 'Ouali',
                'prenom'      => 'Rachid',
                'mot_de_passe' => Hash::make('password'),
                'actif'       => true,
            ]
        );

        DB::table('unites')->upsert(
            [
                ['nom' => 'pièce', 'description' => null, 'actif' => true, 'created_at' => $now, 'updated_at' => $now],
                ['nom' => 'kg', 'description' => null, 'actif' => true, 'created_at' => $now, 'updated_at' => $now],
                ['nom' => 'L', 'description' => null, 'actif' => true, 'created_at' => $now, 'updated_at' => $now],
                ['nom' => 'm', 'description' => null, 'actif' => true, 'created_at' => $now, 'updated_at' => $now],
            ],
            ['nom'],
            ['description', 'actif', 'updated_at']
        );

        DB::table('marques')->upsert(
            [
                ['nom' => 'Lesieur Cristal', 'description' => 'Leader marocain des huiles et graisses', 'created_at' => $now, 'updated_at' => $now],
                ['nom' => 'Dari', 'description' => 'Expert du couscous et des pâtes', 'created_at' => $now, 'updated_at' => $now],
                ['nom' => 'Centrale Danone', 'description' => 'Produits laitiers frais', 'created_at' => $now, 'updated_at' => $now],
                ['nom' => 'Jaouda', 'description' => 'Coopérative laitière marocaine', 'created_at' => $now, 'updated_at' => $now],
                ['nom' => 'Atay', 'description' => 'Thé vert de qualité supérieure', 'created_at' => $now, 'updated_at' => $now],
                ['nom' => 'Sidi Ali', 'description' => 'Eau minérale naturelle', 'created_at' => $now, 'updated_at' => $now],
                ['nom' => 'Ain Saïss', 'description' => 'Eau de source', 'created_at' => $now, 'updated_at' => $now],
                ['nom' => 'Coca-Cola', 'description' => 'Boissons gazeuses', 'created_at' => $now, 'updated_at' => $now],
            ],
            ['nom'],
            ['description', 'updated_at']
        );

        $this->call(ModePaiementSeeder::class);

        $marqueIdsByName = DB::table('marques')->pluck('id', 'nom')->toArray();

        if (
            Category::query()->exists() ||
            SousCategorie::query()->exists() ||
            Article::query()->exists() ||
            Client::query()->exists() ||
            Fournisseur::query()->exists()
        ) {
            return;
        }

        // ─────────────────────────────────────────────────────────────────────
        // REAL MOROCCAN CATALOGUE
        // ─────────────────────────────────────────────────────────────────────

        $catalogue = [
            [
                'nom'         => 'Épicerie & Conserves',
                'description' => 'Produits de base du garde-manger marocain',
                'sous_categories' => [
                    [
                        'nom'         => 'Huiles & Graisses',
                        'description' => 'Huiles végétales et corps gras',
                        'articles'    => [
                            [
                                'code'        => 'ART-HUI001',
                                'nom'         => 'Huile d\'olive extra vierge Moulins de la Koutoubia',
                                'description' => 'Huile d\'olive marocaine première pression à froid, 1 L',
                                'unite'       => 'L',
                                'image'       => 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=400',
                                'prix_achat'  => 38.00,
                                'prix_vente'  => 52.00,
                                'prix_gros'   => 46.00,
                                'marque'      => 'Lesieur Cristal',
                                'seuil_min'   => 10,
                            ],
                            [
                                'code'        => 'ART-HUI002',
                                'nom'         => 'Huile de table Lesieur Cristal 5 L',
                                'description' => 'Huile de tournesol raffinée, bidon 5 litres',
                                'unite'       => 'L',
                                'image'       => 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=400',
                                'prix_achat'  => 65.00,
                                'prix_vente'  => 80.00,
                                'prix_gros'   => 73.00,
                                'marque'      => 'Lesieur Cristal',
                                'seuil_min'   => 8,
                            ],
                            [
                                'code'        => 'ART-HUI003',
                                'nom'         => 'Huile d\'argan alimentaire Zine',
                                'description' => 'Huile d\'argan 100 % pure, pressée artisanalement, 250 ml',
                                'unite'       => 'L',
                                'image'       => 'https://images.unsplash.com/photo-1608228088998-57828365d486?w=400',
                                'prix_achat'  => 95.00,
                                'prix_vente'  => 130.00,
                                'prix_gros'   => 118.00,
                                'seuil_min'   => 5,
                            ],
                        ],
                    ],
                    [
                        'nom'         => 'Épices & Condiments',
                        'description' => 'Épices traditionnelles marocaines',
                        'articles'    => [
                            [
                                'code'        => 'ART-EPI001',
                                'nom'         => 'Ras el-Hanout La Kama 100 g',
                                'description' => 'Mélange d\'épices marocaines traditionnelles, sachet 100 g',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400',
                                'prix_achat'  => 8.00,
                                'prix_vente'  => 14.00,
                                'prix_gros'   => 12.00,
                                'seuil_min'   => 20,
                            ],
                            [
                                'code'        => 'ART-EPI002',
                                'nom'         => 'Safran pur de Taliouine 1 g',
                                'description' => 'Safran IGP Taliouine, pistils entiers, boîte 1 g',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=400',
                                'prix_achat'  => 22.00,
                                'prix_vente'  => 35.00,
                                'prix_gros'   => 30.00,
                                'seuil_min'   => 10,
                            ],
                            [
                                'code'        => 'ART-EPI003',
                                'nom'         => 'Cumin moulu Fadouala 200 g',
                                'description' => 'Cumin finement moulu, qualité supérieure, sachet 200 g',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1506368083636-6defb67639ab?w=400',
                                'prix_achat'  => 6.50,
                                'prix_vente'  => 11.00,
                                'prix_gros'   => 9.50,
                                'seuil_min'   => 15,
                            ],
                            [
                                'code'        => 'ART-EPI004',
                                'nom'         => 'Harissa Brahim\'s 135 g',
                                'description' => 'Pâte de piment harissa, tube 135 g',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1612871689294-5a55c7a59628?w=400',
                                'prix_achat'  => 7.00,
                                'prix_vente'  => 12.00,
                                'prix_gros'   => 10.50,
                                'seuil_min'   => 20,
                            ],
                        ],
                    ],
                    [
                        'nom'         => 'Céréales & Légumineuses',
                        'description' => 'Farines, semoules et légumineuses sèches',
                        'articles'    => [
                            [
                                'code'        => 'ART-CER001',
                                'nom'         => 'Semoule de blé dur Dari 1 kg',
                                'description' => 'Semoule fine pour couscous, paquet 1 kg',
                                'unite'       => 'kg',
                                'image'       => 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?w=400',
                                'prix_achat'  => 6.00,
                                'prix_vente'  => 9.50,
                                'prix_gros'   => 8.20,
                                'marque'      => 'Dari',
                                'seuil_min'   => 30,
                            ],
                            [
                                'code'        => 'ART-CER002',
                                'nom'         => 'Farine de blé Moulin du Souss 5 kg',
                                'description' => 'Farine blanche type 55, sac 5 kg',
                                'unite'       => 'kg',
                                'image'       => 'https://images.unsplash.com/photo-1627485937980-221c88ac04f9?w=400',
                                'prix_achat'  => 22.00,
                                'prix_vente'  => 32.00,
                                'prix_gros'   => 28.00,
                                'seuil_min'   => 20,
                            ],
                            [
                                'code'        => 'ART-CER003',
                                'nom'         => 'Lentilles vertes du Maroc 500 g',
                                'description' => 'Lentilles vertes triées, paquet 500 g',
                                'unite'       => 'kg',
                                'image'       => 'https://images.unsplash.com/photo-1511690743698-d9d85f2fbf38?w=400',
                                'prix_achat'  => 7.50,
                                'prix_vente'  => 12.00,
                                'prix_gros'   => 10.50,
                                'seuil_min'   => 25,
                            ],
                        ],
                    ],
                ],
            ],
            [
                'nom'         => 'Boissons',
                'description' => 'Jus, eaux, thés et boissons marocaines',
                'sous_categories' => [
                    [
                        'nom'         => 'Thés & Infusions',
                        'description' => 'Thés et tisanes du terroir marocain',
                        'articles'    => [
                            [
                                'code'        => 'ART-THE001',
                                'nom'         => 'Thé vert Gunpowder Atay 400 g',
                                'description' => 'Thé vert en perles pour thé à la menthe, boîte métal 400 g',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400',
                                'prix_achat'  => 28.00,
                                'prix_vente'  => 42.00,
                                'prix_gros'   => 37.00,
                                'marque'      => 'Atay',
                                'seuil_min'   => 15,
                            ],
                            [
                                'code'        => 'ART-THE002',
                                'nom'         => 'Thé à la menthe marocain sachet x25 Maghrebi',
                                'description' => 'Infusion menthe poivrée, boîte 25 sachets',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=400',
                                'prix_achat'  => 9.00,
                                'prix_vente'  => 15.00,
                                'prix_gros'   => 13.00,
                                'seuil_min'   => 20,
                            ],
                        ],
                    ],
                    [
                        'nom'         => 'Jus & Eaux',
                        'description' => 'Jus de fruits et eaux minérales',
                        'articles'    => [
                            [
                                'code'        => 'ART-JUS001',
                                'nom'         => 'Eau minérale Sidi Ali 1,5 L',
                                'description' => 'Eau minérale naturelle, bouteille PET 1,5 L',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=400',
                                'prix_achat'  => 4.00,
                                'prix_vente'  => 6.50,
                                'prix_gros'   => 5.50,
                                'marque'      => 'Sidi Ali',
                                'seuil_min'   => 48,
                            ],
                            [
                                'code'        => 'ART-JUS002',
                                'nom'         => 'Jus d\'orange Pom\'s 1 L',
                                'description' => 'Jus d\'orange marocain 100 % pur jus, brique 1 L',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1534353473418-4cfa0d2e3df7?w=400',
                                'prix_achat'  => 7.50,
                                'prix_vente'  => 11.00,
                                'prix_gros'   => 9.50,
                                'marque'      => 'Coca-Cola',
                                'seuil_min'   => 24,
                            ],
                            [
                                'code'        => 'ART-JUS003',
                                'nom'         => 'Eau minérale Ain Saïss 0,5 L pack x6',
                                'description' => 'Pack de 6 bouteilles eau minérale 500 ml',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1592922965978-a4f5d11bee82?w=400',
                                'prix_achat'  => 10.00,
                                'prix_vente'  => 16.00,
                                'prix_gros'   => 14.00,
                                'marque'      => 'Ain Saïss',
                                'seuil_min'   => 24,
                            ],
                        ],
                    ],
                ],
            ],
            [
                'nom'         => 'Produits Laitiers & Œufs',
                'description' => 'Lait, fromages, yaourts et œufs du Maroc',
                'sous_categories' => [
                    [
                        'nom'         => 'Lait & Crème',
                        'description' => 'Lait pasteurisé, UHT et crèmes',
                        'articles'    => [
                            [
                                'code'        => 'ART-LAI001',
                                'nom'         => 'Lait entier Centrale Danone 1 L',
                                'description' => 'Lait entier UHT marocain, brique 1 L',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400',
                                'prix_achat'  => 6.50,
                                'prix_vente'  => 9.00,
                                'prix_gros'   => 8.00,
                                'marque'      => 'Centrale Danone',
                                'seuil_min'   => 48,
                            ],
                            [
                                'code'        => 'ART-LAI002',
                                'nom'         => 'Raïb nature Jaouda 400 g',
                                'description' => 'Lait fermenté nature marocain, pot 400 g',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1571212515416-fef01fc43637?w=400',
                                'prix_achat'  => 5.50,
                                'prix_vente'  => 8.50,
                                'prix_gros'   => 7.50,
                                'marque'      => 'Jaouda',
                                'seuil_min'   => 30,
                            ],
                        ],
                    ],
                    [
                        'nom'         => 'Fromages & Beurre',
                        'description' => 'Fromages frais, fondus et beurre',
                        'articles'    => [
                            [
                                'code'        => 'ART-FRO001',
                                'nom'         => 'Fromage fondu Vache qui rit x8 portions',
                                'description' => 'Fromage fondu, boîte 8 portions 128 g',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=400',
                                'prix_achat'  => 10.00,
                                'prix_vente'  => 15.50,
                                'prix_gros'   => 13.50,
                                'seuil_min'   => 20,
                            ],
                            [
                                'code'        => 'ART-FRO002',
                                'nom'         => 'Beurre doux Centrale Danone 200 g',
                                'description' => 'Beurre doux de qualité, plaquette 200 g',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=400',
                                'prix_achat'  => 14.00,
                                'prix_vente'  => 20.00,
                                'prix_gros'   => 17.50,
                                'marque'      => 'Centrale Danone',
                                'seuil_min'   => 15,
                            ],
                            [
                                'code'        => 'ART-FRO003',
                                'nom'         => 'Fromage frais Kiri x8 portions',
                                'description' => 'Fromage frais à tartiner, 8 portions',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1552767059-ce182ead6c1b?w=400',
                                'prix_achat'  => 11.00,
                                'prix_vente'  => 16.00,
                                'prix_gros'   => 14.00,
                                'seuil_min'   => 15,
                            ],
                        ],
                    ],
                ],
            ],
            [
                'nom'         => 'Boulangerie & Pâtisserie',
                'description' => 'Pains, gâteaux et pâtisseries marocaines',
                'sous_categories' => [
                    [
                        'nom'         => 'Pains & Galettes',
                        'description' => 'Pain de mie, khobz et msemmen',
                        'articles'    => [
                            [
                                'code'        => 'ART-PAN001',
                                'nom'         => 'Pain de mie Siwar 500 g',
                                'description' => 'Pain de mie tranché, sachet 500 g',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400',
                                'prix_achat'  => 7.50,
                                'prix_vente'  => 11.00,
                                'prix_gros'   => 9.50,
                                'seuil_min'   => 20,
                            ],
                            [
                                'code'        => 'ART-PAN002',
                                'nom'         => 'Msemmen artisanal x5 Tafarnout',
                                'description' => 'Crêpes feuilletées marocaines, paquet de 5 pièces',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1551218808-94e220e084d2?w=400',
                                'prix_achat'  => 8.00,
                                'prix_vente'  => 13.00,
                                'prix_gros'   => 11.00,
                                'seuil_min'   => 15,
                            ],
                        ],
                    ],
                    [
                        'nom'         => 'Gâteaux & Biscuits',
                        'description' => 'Biscuits secs, ghoriba et kaab el ghzal',
                        'articles'    => [
                            [
                                'code'        => 'ART-GAT001',
                                'nom'         => 'Ghoriba au sésame artisanale 400 g',
                                'description' => 'Biscuits marocains au sésame et miel, boîte 400 g',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=400',
                                'prix_achat'  => 18.00,
                                'prix_vente'  => 28.00,
                                'prix_gros'   => 24.00,
                                'seuil_min'   => 10,
                            ],
                            [
                                'code'        => 'ART-GAT002',
                                'nom'         => 'Kaab el ghzal pâtisserie Ben Amar 250 g',
                                'description' => 'Cornes de gazelle à la pâte d\'amande, 250 g',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1603532648955-039310d9ed75?w=400',
                                'prix_achat'  => 22.00,
                                'prix_vente'  => 35.00,
                                'prix_gros'   => 30.00,
                                'seuil_min'   => 10,
                            ],
                            [
                                'code'        => 'ART-GAT003',
                                'nom'         => 'Biscuits BN Chocolat 200 g',
                                'description' => 'Biscuits fourrés au chocolat, paquet 200 g',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=400',
                                'prix_achat'  => 6.00,
                                'prix_vente'  => 9.50,
                                'prix_gros'   => 8.20,
                                'seuil_min'   => 25,
                            ],
                        ],
                    ],
                ],
            ],
            [
                'nom'         => 'Hygiène & Beauté',
                'description' => 'Savons, crèmes et produits de beauté marocains',
                'sous_categories' => [
                    [
                        'nom'         => 'Savons & Soins corps',
                        'description' => 'Savon beldi, ghassoul et huiles cosmétiques',
                        'articles'    => [
                            [
                                'code'        => 'ART-SAV001',
                                'nom'         => 'Savon beldi noir naturel 250 g',
                                'description' => 'Savon marocain traditionnel à l\'huile d\'olive et eucalyptus, 250 g',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1600857544200-b2f666a9a2ec?w=400',
                                'prix_achat'  => 12.00,
                                'prix_vente'  => 22.00,
                                'prix_gros'   => 18.00,
                                'seuil_min'   => 20,
                            ],
                            [
                                'code'        => 'ART-SAV002',
                                'nom'         => 'Ghassoul en poudre Zine Atlas 500 g',
                                'description' => 'Argile marocaine purifiante, sachet 500 g',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1608571423902-eed4a5ad8108?w=400',
                                'prix_achat'  => 15.00,
                                'prix_vente'  => 28.00,
                                'prix_gros'   => 23.00,
                                'seuil_min'   => 15,
                            ],
                            [
                                'code'        => 'ART-SAV003',
                                'nom'         => 'Huile d\'argan cosmétique Zitoun 30 ml',
                                'description' => 'Huile d\'argan pure pour soins du visage et cheveux, flacon 30 ml',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1608228088998-57828365d486?w=400',
                                'prix_achat'  => 35.00,
                                'prix_vente'  => 60.00,
                                'prix_gros'   => 52.00,
                                'seuil_min'   => 10,
                            ],
                        ],
                    ],
                    [
                        'nom'         => 'Hygiène dentaire & corporelle',
                        'description' => 'Dentifrices, déodorants et accessoires',
                        'articles'    => [
                            [
                                'code'        => 'ART-HYG001',
                                'nom'         => 'Dentifrice Colgate Total 75 ml',
                                'description' => 'Dentifrice protection complète, tube 75 ml',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1607613009820-a29f7bb81c04?w=400',
                                'prix_achat'  => 12.00,
                                'prix_vente'  => 18.00,
                                'prix_gros'   => 15.50,
                                'seuil_min'   => 20,
                            ],
                            [
                                'code'        => 'ART-HYG002',
                                'nom'         => 'Shampoing Pantene Pro-V 400 ml',
                                'description' => 'Shampoing réparateur, flacon 400 ml',
                                'unite'       => 'pièce',
                                'image'       => 'https://images.unsplash.com/photo-1585751119414-ef2636f8aede?w=400',
                                'prix_achat'  => 28.00,
                                'prix_vente'  => 42.00,
                                'prix_gros'   => 37.00,
                                'seuil_min'   => 15,
                            ],
                        ],
                    ],
                ],
            ],
        ];

        $categories    = collect();
        $sousCategories = collect();
        $articles      = collect();

        foreach ($catalogue as $catData) {
            $category = Category::query()->create([
                'nom'         => $catData['nom'],
                'description' => $catData['description'],
            ]);
            $categories->push($category);

            foreach ($catData['sous_categories'] as $scData) {
                $sc = SousCategorie::query()->create([
                    'categorie_id' => $category->id,
                    'nom'         => $scData['nom'],
                    'description' => $scData['description'],
                ]);
                $sousCategories->push($sc);

                foreach ($scData['articles'] as $artData) {
                    $article = Article::query()->create([
                        'sous_categorie_id' => $sc->id,
                        'marque_id'         => isset($artData['marque']) ? ($marqueIdsByName[$artData['marque']] ?? null) : null,
                        'code_article'      => $artData['code'],
                        'nom'               => $artData['nom'],
                        'description'       => $artData['description'],
                        'unite'             => $artData['unite'],
                        'image'             => $artData['image'],
                        'actif'             => true,
                    ]);

                    PrixArticle::query()->create([
                        'article_id' => $article->id,
                        'prix_achat' => $artData['prix_achat'],
                        'prix_vente' => $artData['prix_vente'],
                        'prix_gros'  => $artData['prix_gros'],
                        'prix_promo' => null,
                    ]);

                    Stock::query()->create([
                        'article_id' => $article->id,
                        'quantite'   => 0,
                        'seuil_min'  => $artData['seuil_min'],
                    ]);

                    $articles->push($article);
                }
            }
        }

        // ─── Fournisseurs marocains réels ────────────────────────────────────
        $fournisseursData = [
            ['nom' => 'Centrale Danone Maroc',   'telephone' => '+212522366000', 'email' => 'contact@centraledanone.ma',   'adresse' => '48, boulevard Al Massira Al Khadra, Casablanca'],
            ['nom' => 'Lesieur Cristal',          'telephone' => '+212522354040', 'email' => 'info@lesieurdz.ma',           'adresse' => 'Route de Rabat, Aïn Sebaâ, Casablanca'],
            ['nom' => 'Cosumar',                  'telephone' => '+212522676767', 'email' => 'commercial@cosumar.co.ma',    'adresse' => '8, rue El Araar, Casablanca'],
            ['nom' => 'Label\'Vie Grossiste',     'telephone' => '+212537570100', 'email' => 'grossiste@labelvie.ma',       'adresse' => 'Km 13,5, Route de Rabat, Salé'],
            ['nom' => 'Bimo Biscuits',            'telephone' => '+212522400400', 'email' => 'ventes@bimo.ma',             'adresse' => 'Zone Industrielle Sidi Bernoussi, Casablanca'],
        ];

        $fournisseurs = collect();
        foreach ($fournisseursData as $fd) {
            $fournisseurs->push(Fournisseur::query()->create([
                'nom'       => $fd['nom'],
                'telephone' => $fd['telephone'],
                'email'     => $fd['email'],
                'adresse'   => $fd['adresse'],
                'actif'     => true,
            ]));
        }

        // ─── Clients marocains réels ─────────────────────────────────────────
        $clientsData = [
            ['nom' => 'Fatima Zahra Bennani',   'telephone' => '+212661234501', 'email' => 'fz.bennani@gmail.com',       'adresse' => '12, rue Ibn Battouta, Fès',               'type_client' => 'detail'],
            ['nom' => 'Hassan El Idrissi',      'telephone' => '+212662345602', 'email' => 'h.elidrissi@yahoo.fr',       'adresse' => '34, avenue Mohammed V, Rabat',            'type_client' => 'gros'],
            ['nom' => 'Khadija Ouazzani',       'telephone' => '+212663456703', 'email' => 'k.ouazzani@hotmail.com',     'adresse' => '7, bd Zerktouni, Casablanca',             'type_client' => 'detail'],
            ['nom' => 'Mohammed Tazi',          'telephone' => '+212664567804', 'email' => 'mtazi.commerce@gmail.com',   'adresse' => '56, route de Marrakech, Beni Mellal',     'type_client' => 'gros'],
            ['nom' => 'Aicha Chraibi',          'telephone' => '+212665678905', 'email' => 'a.chraibi@gmail.com',        'adresse' => '23, quartier Agdal, Rabat',               'type_client' => 'detail'],
            ['nom' => 'Youssef Benkirane',      'telephone' => '+212666789006', 'email' => 'y.benkirane@gmail.com',      'adresse' => '89, rue Tarik Ibn Ziad, Tanger',          'type_client' => 'gros'],
            ['nom' => 'Naima El Amrani',        'telephone' => '+212667890107', 'email' => 'n.elamrani@hotmail.fr',      'adresse' => '15, avenue Hassan II, Meknès',            'type_client' => 'detail'],
            ['nom' => 'Rachid Benjelloun',      'telephone' => '+212668901208', 'email' => 'r.benjelloun@gmail.com',     'adresse' => '44, bd de la Résistance, Casablanca',     'type_client' => 'gros'],
            ['nom' => 'Souad Lahlou',           'telephone' => '+212669012309', 'email' => 's.lahlou@yahoo.com',         'adresse' => '3, derb El Hammam, Marrakech',            'type_client' => 'detail'],
            ['nom' => 'Omar El Fassi',          'telephone' => '+212660123410', 'email' => 'o.elfassi@commerce.ma',      'adresse' => '67, avenue Palestine, Oujda',             'type_client' => 'gros'],
            ['nom' => 'Zineb Alaoui',           'telephone' => '+212661234511', 'email' => 'z.alaoui@gmail.com',         'adresse' => '8, rue Moulay Rachid, Agadir',            'type_client' => 'detail'],
            ['nom' => 'Mehdi Naciri',           'telephone' => '+212662345612', 'email' => 'm.naciri@pro.ma',            'adresse' => '22, zone commerciale Hay Hassani, Casab', 'type_client' => 'gros'],
        ];

        $clients = collect();
        foreach ($clientsData as $cd) {
            $clients->push(Client::query()->create([
                'nom'         => $cd['nom'],
                'telephone'   => $cd['telephone'],
                'email'       => $cd['email'],
                'adresse'     => $cd['adresse'],
                'type_client' => $cd['type_client'],
                'actif'       => true,
            ]));
        }

        // ─── Commandes de vente ──────────────────────────────────────────────
        $stockByArticle = Stock::query()->pluck('quantite', 'article_id')->map(fn($v) => (float) $v)->toArray();
        $articlesById   = $articles->keyBy('id');

        $statutsVente = ['payée', 'payée', 'payée', 'payée', 'payée', 'payée', 'payée', 'payée', 'en_attente', 'confirmée', 'annulée', 'en_attente', 'payée', 'confirmée', 'annulée'];

        for ($i = 0; $i < 15; $i++) {
            $statut = $statutsVente[$i];
            $client = $clients->random();

            $commande = CommandeVente::query()->create([
                'client_id'     => $client->id,
                'statut'        => $statut,
                'date_commande' => now()->subDays(rand(0, 10)),
                'note'          => null,
                'utilisateur_id' => $vendeur->id,
            ]);

            $lignesCount  = rand(1, 4);
            $picked       = [];
            $montantTotal = 0.0;
            $montantRemise = 0.0;
            $linesCreated = 0;

            for ($j = 0; $j < $lignesCount; $j++) {
                $candidates = array_filter($stockByArticle, fn($q) => $q > 0);
                if (!$candidates) break;

                $articleId = (int) array_rand($candidates);
                if (isset($picked[$articleId])) continue;
                $picked[$articleId] = true;

                $article = $articlesById->get($articleId);
                if (!$article) continue;

                $prix        = PrixArticle::query()->where('article_id', $articleId)->first();
                $prixUnitaire = $client->type_client === 'gros'
                    ? (float) ($prix->prix_gros ?? $prix->prix_vente)
                    : (float) $prix->prix_vente;

                $quantiteMax = max(1.0, min(20.0, $stockByArticle[$articleId]));
                $quantite    = round(rand(1, (int)$quantiteMax) + rand(0, 9) / 10, 1);
                $remise      = (rand(1, 5) === 1) ? round(rand(5, 10) + rand(0, 9) / 10, 2) : 0;

                LigneCommandeVente::query()->create([
                    'commande_vente_id' => $commande->id,
                    'article_id'        => $articleId,
                    'quantite'          => $quantite,
                    'prix_unitaire'     => $prixUnitaire,
                    'remise'            => $remise,
                ]);
                $linesCreated++;

                $ligneTotal    = $quantite * $prixUnitaire;
                $ligneRemise   = $ligneTotal * ($remise / 100.0);
                $montantTotal += $ligneTotal;
                $montantRemise += $ligneRemise;

                if ($statut === 'payée') {
                    $stockByArticle[$articleId] -= $quantite;
                    Stock::query()->where('article_id', $articleId)->update([
                        'quantite' => DB::raw('quantite - ' . (float) $quantite),
                    ]);

                    MouvementStock::query()->create([
                        'article_id'     => $articleId,
                        'type_mouvement' => 'sortie',
                        'motif'          => 'vente',
                        'quantite'       => $quantite,
                        'reference_id'   => $commande->id,
                        'reference_type' => 'vente',
                        'utilisateur_id' => $vendeur->id,
                    ]);
                }
            }

            if ($statut === 'payée' && $linesCreated > 0) {
                $montantPaye = max(0.0, $montantTotal - $montantRemise);

                $vente = Vente::query()->create([
                    'commande_vente_id' => $commande->id,
                    'client_id'         => $commande->client_id,
                    'montant_total'     => $montantTotal,
                    'montant_remise'    => $montantRemise,
                    'montant_paye'      => $montantPaye,
                    'mode_paiement'     => collect(['espèces', 'carte', 'virement', 'chèque'])->random(),
                    'date_vente'        => now(),
                    'utilisateur_id'    => $vendeur->id,
                ]);

                HistoriqueAction::query()->create([
                    'utilisateur_id'   => $vendeur->id,
                    'action'           => 'payer',
                    'table_cible'      => 'commandes_vente',
                    'enregistrement_id' => $commande->id,
                    'details'          => [
                        'vente_id'      => $vente->id,
                        'montant_total' => $montantTotal,
                        'montant_remise' => $montantRemise,
                        'montant_paye'  => $montantPaye,
                    ],
                ]);
            } elseif ($statut === 'payée') {
                $commande->statut = 'en_attente';
                $commande->save();
            }
        }

        // ─── Sorties diverses ────────────────────────────────────────────────
        for ($i = 0; $i < 6; $i++) {
            $candidates = array_filter($stockByArticle, fn($q) => $q > 0);
            if (!$candidates) break;

            $articleId = (int) array_rand($candidates);
            $qteMax    = max(1.0, min(10.0, $stockByArticle[$articleId]));
            $qte       = round(rand(1, (int)$qteMax) + rand(0, 9) / 10, 1);
            $motif     = collect(['perte', 'don', 'ajustement'])->random();

            $sortie = Sortie::query()->create([
                'article_id'    => $articleId,
                'motif'         => $motif,
                'quantite'      => $qte,
                'note'          => null,
                'utilisateur_id' => $magasinier->id,
            ]);

            $stockByArticle[$articleId] -= $qte;
            Stock::query()->where('article_id', $articleId)->update([
                'quantite' => DB::raw('quantite - ' . (float) $qte),
            ]);

            MouvementStock::query()->create([
                'article_id'     => $articleId,
                'type_mouvement' => 'sortie',
                'motif'          => $motif,
                'quantite'       => $qte,
                'reference_id'   => $sortie->id,
                'reference_type' => 'sortie',
                'utilisateur_id' => $magasinier->id,
            ]);
        }

        // ─── Promotions ──────────────────────────────────────────────────────
        $promotions = [
            ['name' => 'Promo Ramadan Épices',    'type' => 'pourcentage',   'value' => 15.00, 'target_type' => 'category', 'target_id' => $categories->firstWhere('nom', 'Épicerie & Conserves')?->id ?? $categories->first()->id, 'start_date' => now()->format('Y-m-d'), 'end_date' => now()->addDays(30)->format('Y-m-d'), 'is_active' => true],
            ['name' => 'Offre Huile Argan -10%',  'type' => 'pourcentage',   'value' => 10.00, 'target_type' => 'article',  'target_id' => $articles->firstWhere('code_article', 'ART-HUI003')?->id ?? $articles->first()->id, 'start_date' => now()->format('Y-m-d'), 'end_date' => now()->addDays(15)->format('Y-m-d'), 'is_active' => true],
            ['name' => 'Remise Gros Client',       'type' => 'pourcentage',   'value' => 5.00,  'target_type' => 'client',   'target_id' => $clients->firstWhere('type_client', 'gros')?->id ?? $clients->first()->id, 'start_date' => now()->subDays(5)->format('Y-m-d'), 'end_date' => now()->addDays(25)->format('Y-m-d'), 'is_active' => true],
            ['name' => 'Réduction Thé Gunpowder',  'type' => 'montant_fixe',  'value' => 5.00,  'target_type' => 'article',  'target_id' => $articles->firstWhere('code_article', 'ART-THE001')?->id ?? $articles->first()->id, 'start_date' => now()->format('Y-m-d'), 'end_date' => now()->addDays(20)->format('Y-m-d'), 'is_active' => true],
            ['name' => 'Promo Été Boissons',       'type' => 'pourcentage',   'value' => 8.00,  'target_type' => 'category', 'target_id' => $categories->firstWhere('nom', 'Boissons')?->id ?? $categories->first()->id, 'start_date' => now()->addDays(10)->format('Y-m-d'), 'end_date' => now()->addDays(40)->format('Y-m-d'), 'is_active' => false],
            ['name' => 'Offre Savon Beldi',        'type' => 'montant_fixe',  'value' => 3.00,  'target_type' => 'article',  'target_id' => $articles->firstWhere('code_article', 'ART-SAV001')?->id ?? $articles->first()->id, 'start_date' => now()->subDays(2)->format('Y-m-d'), 'end_date' => now()->addDays(12)->format('Y-m-d'), 'is_active' => true],
            ['name' => 'Promo Pâtisseries Fêtes',  'type' => 'pourcentage',   'value' => 20.00, 'target_type' => 'category', 'target_id' => $categories->firstWhere('nom', 'Boulangerie & Pâtisserie')?->id ?? $categories->first()->id, 'start_date' => now()->format('Y-m-d'), 'end_date' => now()->addDays(7)->format('Y-m-d'), 'is_active' => true],
            ['name' => 'Réduction Lait Danone',    'type' => 'montant_fixe',  'value' => 1.50,  'target_type' => 'article',  'target_id' => $articles->firstWhere('code_article', 'ART-LAI001')?->id ?? $articles->first()->id, 'start_date' => now()->subDays(3)->format('Y-m-d'), 'end_date' => now()->addDays(5)->format('Y-m-d'), 'is_active' => false],
        ];

        foreach ($promotions as $promo) {
            Promotion::query()->create($promo);
        }

        // ─── Historique actions ──────────────────────────────────────────────
        $tables = ['categories', 'sous_categories', 'articles', 'stock', 'prix_articles', 'fournisseurs', 'commandes_achat', 'lignes_commande_achat', 'clients', 'commandes_vente', 'lignes_commande_vente', 'ventes', 'promotions', 'mouvements_stock', 'sorties'];
        $actions = ['create', 'update', 'delete', 'import', 'export'];
        $users  = [$admin->id, $vendeur->id, $magasinier->id];

        for ($i = 0; $i < 12; $i++) {
            HistoriqueAction::query()->create([
                'utilisateur_id'   => $users[array_rand($users)],
                'action'           => $actions[array_rand($actions)],
                'table_cible'      => $tables[array_rand($tables)],
                'enregistrement_id' => rand(1, 50),
                'details'          => null,
            ]);
        }
    }
}
