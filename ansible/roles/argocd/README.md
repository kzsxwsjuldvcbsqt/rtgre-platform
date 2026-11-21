# Rôle `argocd`

Amorce Argo CD depuis le plan de contrôle ([ADR 0010](../../../docs/adr/0010-deployer-en-gitops-avec-argo-cd.md)), puis lui laisse la main.

1. Le rôle lit le dépôt suivi et l'espace de noms dans les valeurs du chart `kubernetes/apps` : ils ne sont écrits que là.
2. Si l'application racine n'existe pas, il rend le chart `kubernetes/argocd` avec `helm template` sur le poste de contrôle et l'applique, puis attend les composants.
3. Si le Secret du dépôt n'existe pas, il génère une paire de clés sur le poste de contrôle, enregistre la partie publique comme clé de déploiement en lecture seule avec `gh`, et dépose la partie privée dans le Secret. Le dossier de travail est supprimé dans tous les cas.
4. Si l'application racine n'existe pas, il rend le chart `kubernetes/apps` et l'applique.
5. Il attend que toutes les applications soient `Synced` et `Healthy`.

Helm et `gh` sont fournis par `mise.toml`. `gh` doit être authentifié avec un compte qui administre le dépôt.

## Choix notables

- **Amorçage seulement** : tant que l'application racine existe, le rôle ne touche plus à l'installation. Les mises à jour d'Argo CD passent par le dépôt, comme celles des autres applications. Sur un cluster reconstruit, le rôle réinstalle tout.
- **Gestionnaire de champs `argocd-controller`** : le chart est appliqué côté serveur sous le nom qu'utilise Argo CD. Quand son application reprend ces objets, elle en est déjà propriétaire : pas de conflit, pas de redémarrage des pods.
- **La clé privée ne touche ni Git ni le disque du nœud** : elle passe par l'entrée standard de `kubectl`, dans une tâche dont le journal est masqué.
- **Une clé par cluster** : `argocd_deploy_key_title` la désigne dans le dépôt. À l'enregistrement, une ancienne clé du même titre est retirée. Le renouvellement est décrit dans le [runbook](../../../docs/runbooks/renouveler-la-cle-de-deploiement-d-argocd.md).
- **`gh` ne renvoie rien quand le dépôt n'a aucune clé**, pas même une liste vide : le rôle traite ce cas.
