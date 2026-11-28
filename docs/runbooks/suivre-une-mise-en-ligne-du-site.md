# Suivre une mise en ligne du site

Une modification fusionnée dans le dépôt [rtgre](https://github.com/kzsxwsjuldvcbsqt/rtgre) arrive sur rtgre.fr sans intervention ([ADR 0028](../adr/0028-mettre-en-ligne-l-image-du-site-par-un-workflow-declenche.md)). Elle passe par cinq étapes, une dizaine de minutes en tout :

| Étape | Où | Durée habituelle |
| --- | --- | --- |
| 1. L'image est construite, analysée, publiée et signée | workflow `Image` de rtgre | 3 à 5 minutes |
| 2. Ce workflow lance la promotion et attend son résultat | travail « Image (promote to the platform) » de rtgre | quelques secondes |
| 3. L'empreinte est proposée, contrôlée, puis fusionnée | workflow `Promote` de ce dépôt | 3 à 5 minutes |
| 4. Argo CD relit le dépôt et déploie | cluster | de quelques secondes à 5 minutes |
| 5. Le site est généré avec la nouvelle image | Job `rtgre-generator-sync` | une vingtaine de secondes |

Les commandes `gh` se lancent depuis ce dépôt. Celles du cluster passent par le Bastion ([se-connecter-a-un-noeud](se-connecter-a-un-noeud.md)).

Mesuré le 28 novembre 2026, du lancement du workflow `Image` au site généré : 9 minutes 54 secondes. L'image a pris 3 minutes, la promotion 2 minutes 15 secondes, Argo CD 4 minutes 5 secondes, la génération 19 secondes. Le même jour, une promotion lancée seule a été déployée 26 secondes après sa fusion.

## Voir où en est une mise en ligne

```bash
gh run list --repo kzsxwsjuldvcbsqt/rtgre --workflow image.yml --branch main --limit 3
gh run list --workflow promote.yml --limit 3
gh pr list --state all --search "head:chore/image-" --limit 3
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n argocd get applications.argoproj.io rtgre
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n rtgre get job rtgre-generator-sync
```

- Le workflow `Image` de rtgre est vert seulement si la promotion a abouti : il attend le workflow `Promote`.
- La dernière pull request `chore/image-…` est fusionnée, et son empreinte est celle de `generator.image.tag` dans `kubernetes/rtgre/values.yaml`.
- L'application `rtgre` est `Synced` et `Healthy`, et le Job `rtgre-generator-sync` est `Complete`, plus récent que la fusion.

## Une mise en ligne n'arrive pas

| Où cela s'arrête | Cause | Que faire |
| --- | --- | --- |
| Le workflow `Image` échoue avant de publier | Le site ne se construit pas, ou l'image porte une vulnérabilité. | Corriger dans le dépôt rtgre : rien n'a été publié. |
| Le travail « Image (promote to the platform) » est ignoré | La variable `PLATFORM_REPOSITORY` manque dans rtgre : la promotion n'est pas configurée. | « Recréer les applications », plus bas. En attendant, « Mettre en ligne à la main ». |
| Ce travail, ou `Promote`, échoue en créant son jeton | L'application GitHub a été désinstallée, ou sa clé a été révoquée. | « Recréer les applications ». |
| `Promote` répond « aucune signature de… » | L'image du registre n'est pas signée par le workflow `image.yml` de rtgre sur `main`. | Ne rien contourner. Chercher qui a publié cette image : registre du dépôt rtgre, exécutions du workflow `Image`. |
| `Promote` échoue en attendant un contrôle | Un contrôle de la pull request a échoué deux fois. La pull request reste ouverte. | Lire le contrôle. S'il concerne l'image du site, corriger dans rtgre. S'il n'a pas de rapport, comme une vulnérabilité publiée dans une autre image, le traiter ici d'abord, puis « Relancer une promotion ». |
| `Promote` échoue à la fusion | `main` a avancé pendant les contrôles : la branche n'est plus à jour. | « Relancer une promotion » : elle repart de la pointe de `main`. |
| La pull request est fusionnée, le site ne change pas | Argo CD n'a pas encore relu le dépôt, ou la génération a échoué. | Attendre cinq minutes : Argo CD relit le dépôt toutes les deux à trois minutes, et garde un moment en mémoire la révision qu'il a lue. Sinon, [rétablir l'application](retablir-une-application-argocd.md) ou [suivre la génération](suivre-la-generation-du-site.md). |

## Relancer une promotion

```bash
gh workflow run promote.yml --ref main
```

Le workflow ne reçoit aucun paramètre : il lit l'empreinte que porte le tag dans le registre. Si elle est déjà celle du dépôt, il ne fait rien. Une pull request `chore/image-…` restée ouverte est fermée ou recréée par la promotion suivante.

## Mettre en ligne à la main

Quand le workflow `Promote` ne peut pas tourner, le même script fait le travail depuis un poste, et la pull request suit le chemin habituel :

```bash
git switch main && git pull
mise exec -- scripts/ci/promote-signed-images.sh
git switch --create chore/image-rtgre-manuelle
git commit --all --message "chore(deps): met à jour l'image du site"
git push --set-upstream origin chore/image-rtgre-manuelle
gh pr create
```

Le script refuse une image qui n'est pas signée par l'identité attendue, comme le fait la CI. La pull request remplit le modèle du dépôt.

## Revenir à l'image précédente

Annuler la fusion de la promotion, par une pull request :

```bash
git switch main && git pull
git switch --create revert/image-rtgre
git revert --mainline 1 <commit de fusion de la promotion>
git push --set-upstream origin revert/image-rtgre
gh pr create
```

Argo CD redéploie l'image précédente, et le site est généré avec elle. **La promotion suivante remettra la dernière image du registre** : corriger le site dans rtgre avant d'y fusionner autre chose, et ne pas relancer `Promote` d'ici là.

## Recréer les applications

La promotion repose sur deux applications GitHub, qui n'ont qu'un droit chacune et ne sont installées que sur ce dépôt. Elles se créent dans « Settings », « Developer settings », « GitHub Apps », sans webhook.

| Application | Droit sur ce dépôt | Sa clé est rangée dans | Sous les noms |
| --- | --- | --- | --- |
| Promotion | « Contents » et « Pull requests », en écriture | l'environnement `promotion` de ce dépôt | variable `PROMOTION_APP_CLIENT_ID`, secret `PROMOTION_APP_PRIVATE_KEY` |
| Déclenchement | « Actions », en écriture | l'environnement `platform` du dépôt rtgre | variable `PLATFORM_TRIGGER_APP_CLIENT_ID`, secret `PLATFORM_TRIGGER_APP_PRIVATE_KEY` |

Pour chacune :

1. Créer l'application avec son seul droit, puis l'installer sur ce dépôt uniquement (« Install App », « Only select repositories »).
2. Relever son « Client ID » et générer une clé privée (« Generate a private key ») : GitHub télécharge un fichier `.pem`.
3. Ranger l'identifiant et la clé, sans que la clé n'apparaisse à l'écran. Pour l'application de promotion :

   ```bash
   gh variable set PROMOTION_APP_CLIENT_ID --env promotion --body "<Client ID>"
   gh secret set PROMOTION_APP_PRIVATE_KEY --env promotion < <fichier .pem>
   ```

   Pour l'application de déclenchement :

   ```bash
   gh variable set PLATFORM_TRIGGER_APP_CLIENT_ID --repo kzsxwsjuldvcbsqt/rtgre --env platform --body "<Client ID>"
   gh secret set PLATFORM_TRIGGER_APP_PRIVATE_KEY --repo kzsxwsjuldvcbsqt/rtgre --env platform < <fichier .pem>
   ```

4. Supprimer le fichier `.pem` du poste.

Les deux environnements n'acceptent que la branche `main` (« Settings », « Environments », « Deployment branches »). La variable `PLATFORM_REPOSITORY` du dépôt rtgre porte le nom de ce dépôt : sans elle, rtgre publie son image sans lancer de promotion.

Vérifier ensuite par « Relancer une promotion », puis par une fusion dans rtgre.

## Renouveler une clé

À faire si une clé a pu fuiter. Dans la page de l'application, générer une nouvelle clé, la ranger comme à l'étape 3, puis supprimer l'ancienne dans la même page (« Private keys », « Delete »). Entre les deux, les deux clés sont valables : rien ne s'interrompt.
