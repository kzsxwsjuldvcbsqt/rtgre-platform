# Reconstruire la plateforme

Recréer un nœud, ou les deux, puis remonter le cluster jusqu'au site servi. À utiliser après la perte d'un nœud, pour lui donner une image plus récente, ou pour vérifier que le dépôt suffit toujours à tout refaire.

Le dépôt décrit tout, sauf ce que cette procédure rétablit : la clé de déploiement d'Argo CD et le Secret du courrier des alertes. Ce qui est perdu avec les nœuds : l'historique des métriques et des journaux, et les silences d'Alertmanager.

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

Relire le plan dans l'exécution, puis l'approuver dans l'environnement `production`. Il ne doit contenir que le remplacement des nœuds nommés et, pour `wk-1`, celui de ses deux entrées dans le load balancer.

Recréer `wk-1` seul garde le cluster : passer alors directement à l'étape 3, le playbook le fait rejoindre. Recréer `cp-1` perd le cluster : `wk-1` doit être recréé avec lui.

## 3. Remonter le cluster

```bash
scripts/bastion-ssh-config.sh
```

Les nœuds recréés ont de nouvelles clés d'hôte. Si SSH refuse une adresse déjà connue, oublier l'ancienne clé avec `ssh-keygen -R <adresse>`, pour chaque nœud.

```bash
cd ansible
ansible-playbook playbooks/site.yml
```

Le playbook durcit les nœuds, installe Kubernetes, initialise le plan de contrôle, pose Cilium, fait rejoindre le nœud de travail, crée les dossiers des volumes, puis installe Argo CD avec une nouvelle clé de déploiement. Argo CD déploie ensuite tout le reste depuis `main`.

## 4. Rétablir ce qui ne vit pas dans le dépôt

```bash
scripts/alertmanager-email.sh
```

Le mot de passe initial d'Argo CD est neuf : [acceder-a-argocd](acceder-a-argocd.md).

## 5. Vérifier, puis ramener les visiteurs

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n argocd get applications.argoproj.io
curl -s -o /dev/null -w '%{http_code}\n' https://test.rtgre.fr/
```

Toutes les applications sont `Synced` et `Healthy`, et le site répond 200 sous son nom de test, avec un certificat neuf. Ramener alors les visiteurs vers le cluster ([basculer-rtgre-fr](basculer-rtgre-fr.md)).
