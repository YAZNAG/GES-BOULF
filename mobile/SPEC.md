# Boulfrik mobile — cahier des charges

Application Flutter (Android d'abord, iOS ensuite) du supermarché Boulfrik.
Elle consomme l'API Laravel du dossier `backend/` (production : `https://boulfrik.optizaworks.com`).
Langue de l'interface : français, noms de produits aussi en arabe (affichés RTL).

## Parcours

1. **Connexion** (e-mail + mot de passe) → jeton Sanctum gardé en stockage sécurisé.
2. **Tableau de bord** soigné : ventes du jour, encaissé, ventes du mois, crédit clients, crédit fournisseurs,
   alertes stock (ruptures, sous le seuil), produits à tarifer, graphe des 7 derniers jours, top 5 produits du mois,
   dernières ventes. Tirer pour rafraîchir.
3. **Barre de navigation du bas** : Accueil · Caisse · Produits · Plus.
4. **Caisse (POS)** :
   - ajout au panier par **scan caméra** (code-barres EAN) ou par **barre de recherche** ;
   - la recherche accepte un **code-barres**, un **nom français** ou un **nom arabe** (même champ) ;
   - un code-barres scanné/saisi ajoute directement l'article (s'il est déjà au panier : quantité +1) ;
   - panier : quantité +/−, saisie de quantité (décimales pour le vrac), suppression par glissement, total ;
   - client : **« Client de passage »** par défaut, ou choix d'un client existant (recherche) ;
   - paiement : mode (espèces, carte, chèque, virement), montant reçu, rendu monnaie ;
     si client choisi et paiement partiel → le reste passe en **crédit client** (le serveur le gère) ;
     client de passage → paiement complet obligatoire ;
   - validation → écran de succès avec n° de facture ; panier vidé.
   - Un produit non tarifé (prix 0) ou inactif ne peut pas être ajouté (message clair).
5. **Produits** : liste paginée avec recherche (code-barres, FR, AR), scan, filtres (famille/catégorie, « À tarifer », « En rupture »),
   **page détail** : photo, noms FR/AR, marque, code-barres, catégorie, prix achat/vente/gros/promo, marge, stock, seuil, description.
   Modification rapide des prix depuis le détail (PUT /api/tarifs/{id}).
6. **Plus** : carte profil (nom, rôle, e-mail, déconnexion), puis la liste des modules :
   - Tarifs de vente
   - Clients · Crédit clients (encaisser un règlement)
   - Fournisseurs · Crédit fournisseurs (régler un fournisseur, relevé)
   - Stock (articles en stock)
   - Bons de commande (liste, détail, création, confirmer/annuler)
   - Bons de réception (liste, détail, création — directe ou depuis un bon de commande ; scan pour ajouter les lignes ;
     prix d'achat saisi à la réception ; prix de vente facultatif)
   - Entrées de stock (mouvements d'entrée)
   - Historique des paiements fournisseurs
   - Ventes (liste, détail)
   - Utilisateurs (liste, création, activation)
   - Paramètres : Unités, Marques
   - À propos / version de l'application
7. **Mises à jour** :
   - au démarrage, `GET /api/app/version` ; si `build` > build installé → page « Mise à jour disponible »
     (notes + bouton « Télécharger » qui ouvre `apk_url`) ; si `min_build` > build installé → page bloquante ;
   - le projet doit rester compatible **Shorebird** (correctifs de code sans réinstaller) : pas de code natif spécifique.

## Style

- Couleur de marque rouge `#E11D2E`, encre `#0F172A`, gris ardoise `#64748B`, fond `#F6F7FB`, cartes blanches arrondies (16–20).
- Material 3, typographie lisible, en-têtes avec dégradé sombre (comme le site : `#111827 → #3B0B12`).
- Montants : `1 234,50 DH` ; dates `03/10/2026`.
- Listes : chargement progressif (pagination), squelettes, état vide, tirer pour rafraîchir, messages d'erreur clairs.
- Arabe : `Directionality(textDirection: TextDirection.rtl)` pour les noms arabes.

## API (toutes les routes : préfixe `/api`, en-têtes `Accept: application/json`, `Authorization: Bearer <token>`)

Pagination Laravel « classique » : `{ current_page, data: [...], last_page, total, per_page, from, to }` (pas de `meta`).
Erreurs : `{ message, errors?: {champ: [msg]} }` ; 401 = session expirée.

### Authentification
- `POST auth/login` `{email, password}` → `{ token, user: { id, nom, prenom, email, actif, role: { id, nom, permissions: [..]|null } } }`
  (rôle `admin` = tous les droits). 422 identifiants invalides, 403 compte désactivé.
- `GET auth/me` → `{ user }` · `POST auth/logout`.

### Tableau de bord
- `GET m/dashboard` → `{ jour:{ventes,montant,encaisse}, mois:{ventes,montant}, credit_clients, credit_fournisseurs,
  stock:{rupture,sous_seuil}, produits:{total,actifs,a_tarifer}, sept_jours:[{date,jour,montant}],
  top_produits:[{id,nom,image,qte,montant}], dernieres_ventes:[{id,montant_total,montant_paye,mode_paiement,date_vente,client:{id,nom}|null}] }`

### Produits
- `GET articles?q=&per_page=&page=&famille_id=&categorie_id=&sous_categorie_id=&statut=(actif|inactif|a_tarifer|rupture)&sort=(nom|recent|prix_asc|prix_desc)&with_stats=1`
  → page d'articles `{ id, code_article, nom, name_fr, name_ar, description, unite, image ("/storage/..." relatif au serveur), actif,
  marque:{id,nom}|null, prix:{id,prix_achat,prix_vente,prix_gros,prix_promo}|null, stock:{id,quantite,seuil_min}|null,
  sous_categorie:{id,nom,name_fr,categorie:{id,nom,name_fr,famille:{id,nom_fr}}} }` (+ `stats` si with_stats).
  `q` cherche dans nom, name_fr, **name_ar**, code_article, marque. Les nombres arrivent souvent en chaînes ("4.50").
- `GET articles/lookup?code=6111…` → un article (même forme) ou 404 `{message}`.
- `GET articles/{id}` → un article.
- `GET familles?per_page=200` → `{data:[{id,nom_fr,nom_ar,image,categories_count,articles_count}]}`
- `GET categories?per_page=1000&famille_id=` → `{data:[{id,nom,name_fr,name_ar,image,famille_id,articles_count}]}`
- `GET sous_categories?per_page=1000&categorie_id=` → `{data:[{id,nom,name_fr,name_ar,image,categorie_id,articles_count}]}`

### Tarifs de vente
- `GET tarifs?q=&statut=(tarife|a_tarifer|promo|perte|marge_faible|sans_achat)&sort=(nom|vente_asc|vente_desc|marge_asc|marge_desc)&page=&per_page=`
  → page `{ id, nom, name_fr, name_ar, code_article, image, actif, prix_achat, prix_vente, prix_gros, prix_promo, marge, marque, stock:{quantite} }`
  + `stats:{total,tarifes,a_tarifer,promo,perte,marge_moyenne}`.
- `PUT tarifs/{articleId}` `{prix_achat?, prix_vente?, prix_gros?, prix_promo?, actif?}` → `{prix, actif}`
  (un prix de vente > 0 active l'article).

### Caisse
- `POST pos/sale` `{ client_id: null|id, items:[{article_id, quantite, prix_unitaire}], montant_total, montant_paye, mode_paiement: "especes"|"carte"|"cheque"|"virement" }`
  → 201 `{ success, vente_id, facture_id, numero_facture }`. `client_id: null` = client de passage.
  Si `montant_paye < montant_total` avec un client : le reste s'ajoute au crédit du client.
  Prix unitaire = `prix.prix_promo` s'il est > 0, sinon `prix.prix_vente`.

### Clients et crédit client
- `GET m/clients?q=&avec_credit=1&page=` → page `{id,nom,telephone,email,adresse,type_client,solde,actif,ventes_count}` + `stats:{total,avec_credit,credit_total}`.
- `POST clients` `{nom, telephone?, email?, adresse?, type_client: "detail"|"gros"}` ; `PUT clients/{id}`.
- `GET clients/{id}/history` → historique des ventes du client.
- `GET paiements?per_page=` (paiements clients) ; `POST paiements` `{client_id, montant, mode, note?}` → diminue le solde.

### Ventes
- `GET m/ventes?du=YYYY-MM-DD&au=&client_id=&credit=1&q=&page=` → page `{id,montant_total,montant_paye,mode_paiement,date_vente,items_count,
  client:{id,nom}|null, facture:{numero_facture,statut}|null, utilisateur:{id,nom}}` + `resume:{montant,encaisse}`.
- `GET m/ventes/{id}` → vente + `items:[{quantite,prix_unitaire,article:{nom,name_ar,code_article,image,unite}}]`.

### Fournisseurs et crédit fournisseur
- `GET fournisseurs?q=&avec_credit=1&page=&per_page=` → page `{id,code,nom,contact,telephone,email,adresse,ville,ice,rc,solde,plafond_credit,
  delai_paiement,note,actif,commandes_count,receptions_count,total_achats,derniere_reception}` + `stats:{total,actifs,credit_total,avec_credit,depassement}`.
- `GET fournisseurs/{id}` (+ total_achats, total_paye) ; `POST fournisseurs` ; `PUT fournisseurs/{id}` (le solde n'est pas modifiable).
- `GET achats/fournisseurs/{id}/releve` → `{fournisseur, lignes:[{date,type:"reception"|"paiement",libelle,debit,credit,solde}]}`.
- `GET achats/paiements?fournisseur_id=&page=` → page `{id,montant,mode,date_paiement,reference,note,fournisseur:{nom},reception:{numero}|null}`.
- `POST achats/paiements` `{fournisseur_id, montant, mode, date_paiement?, reference?, note?, reception_id?}` → diminue le crédit.

### Bons de commande
- `GET achats/commandes?statut=(brouillon|confirmee|partielle|recue|annulee)&fournisseur_id=&q=&page=`
  → page `{id,numero,statut,date_commande,date_prevue,total,lignes_count,fournisseur:{id,nom}}` + `stats:{<statut>:{n,montant}}`.
- `GET achats/commandes/{id}` → `{..., fournisseur, lignes:[{id,article_id,quantite,quantite_recue,prix_unitaire,article:{...,prix,stock}}], receptions:[...]}`.
- `POST achats/commandes` / `PUT achats/commandes/{id}` (brouillon seulement)
  `{fournisseur_id, date_commande?, date_prevue?, note?, lignes:[{article_id, quantite, prix_unitaire}]}`.
- `POST achats/commandes/{id}/statut` `{statut: "confirmee"|"annulee"|"brouillon"}` ; `DELETE achats/commandes/{id}` (brouillon).

### Bons de réception (entrées en stock, prix d'achat)
- `GET achats/receptions?fournisseur_id=&du=&au=&impaye=1&q=&page=` → page `{id,numero,date_reception,reference_fournisseur,total,montant_paye,reste,
  lignes_count,fournisseur:{nom},commande:{numero}|null}` + `stats:{mois_nombre,mois_montant,credit_total}`.
- `GET achats/receptions/{id}` → `{..., lignes:[{quantite,prix_achat,prix_vente,article:{...}}]}`.
- `POST achats/receptions` `{fournisseur_id, commande_achat_id?, date_reception?, reference_fournisseur?, note?, montant_paye?, mode_paiement?,
  lignes:[{article_id, quantite, prix_achat, prix_vente?, ligne_commande_achat_id?}]}` → stock +, prix d'achat mis à jour,
  bon de commande mis à jour, crédit fournisseur += total − payé.

### Stock
- `GET stock?q=&statut=(en_stock|sous_seuil|rupture)&famille_id=&categorie_id=&sort=(nom|quantite_asc|quantite_desc|valeur)&page=&per_page=&with_stats=1`
  → page `{id,article_id,quantite,seuil_min,prix_achat,prix_vente,valeur_achat,article:{id,nom,name_fr,name_ar,code_article,unite,image,actif,marque,sous_categorie}}`
  + `stats:{en_stock,sous_seuil,rupture,valeur_achat,valeur_vente}`.
- `GET m/mouvements?type=entree|sortie&motif=&article_id=&fournisseur_id=&du=&au=&q=&page=` → page
  `{id,type_mouvement,motif,quantite,note,reference_type,reference_id,created_at,article:{...},fournisseur:{nom}|null,utilisateur:{nom}|null}`.

### Utilisateurs et paramètres
- `GET utilisateurs` (page `{id,nom,prenom,email,actif,role:{id,nom}}`), `POST utilisateurs` `{role_id, nom, prenom?, email, mot_de_passe, actif?}`,
  `PUT utilisateurs/{id}` ; `GET roles`.
- `GET unites?per_page=200` `{id,nom,description,actif}` ; `POST unites` ; `PUT unites/{id}` ; `DELETE unites/{id}`.
- `GET marques?per_page=1000` `{id,nom,image,description}` ; `POST marques` ; `PUT marques/{id}` ; `DELETE marques/{id}`.

### Version
- `GET app/version` (public) → `{version, build, min_build, apk_url, notes}`.

## Tests locaux
- Backend local : `http://10.0.2.2:8000` depuis l'émulateur Android (`php artisan serve` sur 127.0.0.1:8000).
- Compte local de test : `admin@elherii.ma` / `password` (base locale uniquement).
- L'URL du serveur doit être réglable sur l'écran de connexion (« Serveur » repliable), valeur par défaut la production.
