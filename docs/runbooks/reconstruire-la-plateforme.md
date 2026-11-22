# Reconstruire la plateforme

Recréer un nœud, ou les deux, puis remonter le cluster jusqu'au site servi. À utiliser après la perte d'un nœud, pour lui donner une image plus récente, ou pour vérifier que le dépôt suffit toujours à tout refaire.

Le dépôt décrit tout, sauf ce que cette procédure rétablit : la clé de déploiement d'Argo CD, le Secret du courrier des alertes, celui d'Umami et la destination de sa sauvegarde. Ce qui est perdu avec les nœuds : l'historique des métriques et des journaux, et les silences d'Alertmanager. L'historique d'audience, lui, se restaure depuis sa dernière sauvegarde.

Le 22 novembre 2026, il a fallu quarante minutes, avec deux corrections en route (voir l'historique). Sans elles, une demi-heure devrait suffire : c'est une estimation, pas une mesure.

## 1. Avant de détruire

Vérifier qu'Oracle a de la capacité pour recréer les nœuds : sinon, ils manqueront jusqu'à ce qu'elle revienne ([creer-des-noeuds-sans-capacite-a1](creer-des-noeuds-sans-capacite-a1.md)).

```bash
oci compute compute-capacity-report create --compartment-id <OCID de la tenancy> \
  --availability-domain "$(oci iam availability-domain list --query 'data[0].name' --raw-output)" \
  --shape-availabilities '[{"instanceShape":"VM.Standard.A1.Flex","instanceShapeConfig":{"ocpus":1,"memoryInGBs":6}}]' \
  --query 'data."shape-availabilities"[0]."availability-status"'
```

La réponse attendue est `AVAILABLE`. Renvoyer ensuite les visiteurs sur GitHub Pages et attendre cinq minutes ([basculer-rtgre-fr](basculer-rtgre-fr.md)).

## 2. Recréer les nœuds

Le workflow Terraform, lancé à la main avec le nom des nœuds, les détruit puis les recrée :

```bash
gh workflow run terraform.yml --ref main -f replace_nodes="cp-1 wk-1"
```

Relire le plan dans l'exécution, puis l'approuver dans l'environnement `production`. Il ne doit contenir que le remplacement des nœuds nommés et, pour `wk-1`, celui de ses deux entrées dans le load balancer. La destruction prend deux minutes, la création moins d'une.

Recréer `wk-1` seul garde le cluster : le playbook de l'étape 3 le fait rejoindre. Recréer `cp-1` perd le cluster : `wk-1` doit être recréé avec lui.

Si la création échoue après la destruction, les nœuds n'existent plus : corriger, puis relancer le workflow sans paramètre. Son plan ne contient alors que des créations.

## 3. Remonter le cluster

```bash
scripts/bastion-ssh-config.sh
```

Les nœuds recréés ont de nouvelles adresses et de nouvelles clés d'hôte. Si SSH refuse une adresse déjà connue, oublier l'ancienne clé avec `ssh-keygen -R <adresse>`.

```bash
cd ansible
ansible-playbook playbooks/site.yml
```

Le playbook durcit les nœuds, installe Kubernetes, initialise le plan de contrôle, pose Cilium, fait rejoindre le nœud de travail, crée les dossiers des volumes, puis installe Argo CD avec une nouvelle clé de déploiement. Les deux nœuds sont prêts en cinq minutes. Argo CD déploie ensuite tout le reste depuis `main`, en dix à quinze minutes : les applications qui s'attendent l'une l'autre se débloquent au fil de ses essais.

La dernière tâche du playbook attend que toutes les applications soient synchronisées. Si elle expire, les nœuds sont quand même configurés : suivre la suite à la main.

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n argocd get applications.argoproj.io
```

Trois états sont normaux à ce stade : Alertmanager et Umami attendent leur Secret (étape 4), et le certificat attend le retour du DNS (étape 5).

## 4. Rétablir ce qui ne vit pas dans le dépôt

```bash
scripts/alertmanager-email.sh
scripts/umami-secret.sh
scripts/umami-backup-config.sh
```

Umami démarre alors sur une base neuve. Y rejouer la dernière sauvegarde : [sauvegarder-et-restaurer-umami](sauvegarder-et-restaurer-umami.md).

Le mot de passe initial d'Argo CD est neuf : [acceder-a-argocd](acceder-a-argocd.md).

## 5. Ramener les visiteurs, puis attendre le certificat

L'ordre compte. Le certificat couvre `rtgre.fr` et `www.rtgre.fr`, que Let's Encrypt ne valide que s'ils désignent le cluster : **il ne peut pas exister avant le retour du DNS**. Vérifier d'abord que le cluster sert le site, sous le nom de test, sans regarder le certificat :

```bash
curl -sk -o /dev/null -w '%{http_code}\n' https://test.rtgre.fr/
```

Puis ramener les visiteurs vers le cluster ([basculer-rtgre-fr](basculer-rtgre-fr.md)), et suivre le certificat :

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n gateway get certificate,challenge
```

cert-manager vérifie lui-même chaque nom avant de le soumettre, avec le résolveur du cluster : il attend donc que celui-ci oublie l'adresse de GitHub Pages, cinq minutes au plus. **Pendant ce temps, un visiteur qui résout déjà la nouvelle adresse voit une erreur de certificat** ; les autres restent sur GitHub Pages. Si l'attente dépasse dix minutes, lire le message des défis ([suivre-les-certificats](suivre-les-certificats.md)).

## 6. Vérifier

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n argocd get applications.argoproj.io
curl -s -o /dev/null -w '%{http_code}\n' https://rtgre.fr/
scripts/alertmanager-email.sh --test
```

Toutes les applications sont `Synced` et `Healthy`, le site répond 200 avec un certificat valide, et l'alerte d'essai arrive par courrier. Vérifier enfin que les volumes des nœuds sont chiffrés en transit, ce qu'Oracle n'a pas appliqué de lui-même à la recréation du 22 novembre 2026 :

```bash
cd terraform/envs/prod && terraform plan -lock=false
```

Un plan vide le confirme. S'il annonce une modification en place des nœuds, lancer le workflow Terraform sans paramètre et l'approuver : Oracle redémarre alors les deux nœuds, quatre à cinq minutes de coupure, à faire avant de ramener les visiteurs.

## Historique

| Date | Durée | Ce qui a coincé |
| --- | --- | --- |
| 2026-11-22 | 40 minutes de la destruction au site servi avec son certificat | Création refusée faute d'options de lancement complètes ; applications bloquées par leurs dépendances croisées ; certificat retardé par le cache DNS du cluster ([post-mortem](../postmortems/2026-11-22-certificat-invalide-apres-reconstruction.md)). Les trois sont corrigés dans le dépôt. |
