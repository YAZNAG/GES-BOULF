export const PERM_GROUPS = [
  {
    key: 'commandes',
    title: 'Commandes',
    perms: [
      { key: 'commandes.view', label: 'Voir les commandes' },
      { key: 'commandes.edit', label: 'Modifier les commandes' },
      { key: 'commandes.cancel', label: 'Annuler les commandes' },
    ],
  },
  {
    key: 'produits',
    title: 'Produits',
    perms: [
      { key: 'produits.view', label: 'Voir produits' },
      { key: 'produits.create', label: 'Ajouter produits' },
      { key: 'produits.edit', label: 'Modifier / Supprimer' },
    ],
  },
  {
    key: 'categories',
    title: 'Catégories',
    perms: [
      { key: 'categories.view', label: 'Voir catégories' },
      { key: 'categories.manage', label: 'Gérer la structure' },
    ],
  },
  {
    key: 'promotions',
    title: 'Promotions',
    perms: [
      { key: 'promotions.view', label: 'Voir promotions' },
      { key: 'promotions.manage', label: 'Créer / Modifier' },
    ],
  },
  {
    key: 'utilisateurs',
    title: 'Utilisateurs',
    perms: [
      { key: 'utilisateurs.view', label: 'Voir' },
      { key: 'utilisateurs.manage', label: 'Gérer' },
    ],
  },
  {
    key: 'packs',
    title: 'Packs',
    perms: [
      { key: 'packs.view', label: 'Voir packs' },
      { key: 'packs.manage', label: 'Créer / Modifier / Supprimer' },
    ],
  },
  {
    key: 'systeme',
    title: 'Système',
    perms: [
      { key: 'systeme.stats', label: 'Statistiques : Voir' },
      { key: 'systeme.settings', label: 'Paramètres : Accès complet' },
    ],
  },
]

export function uniq(list) {
  const set = new Set()
  for (const x of list || []) set.add(String(x))
  return Array.from(set)
}

export function permissionLabel(perms, groupKey) {
  const group = PERM_GROUPS.find((g) => g.key === groupKey)
  if (!group) return { tone: 'none', label: '—' }
  const total = group.perms.length
  const count = group.perms.filter((p) => perms.has(p.key)).length
  if (count === 0) return { tone: 'none', label: '—' }
  if (count === total) return { tone: 'full', label: 'Complet' }
  return { tone: 'partial', label: 'Partiel' }
}

export const matrixResources = [
  { key: 'commandes', label: 'Commandes' },
  { key: 'produits', label: 'Produits' },
  { key: 'categories', label: 'Catégories' },
  { key: 'promotions', label: 'Promotions' },
  { key: 'utilisateurs', label: 'Utilisateurs' },
  { key: 'systeme', label: 'Système' },
]
