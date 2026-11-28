# 0028. Mettre en ligne l'image du site par un workflow déclenché

- Statut : accepté
- Date : 2026-11-28

## Contexte

Le cluster génère le site avec une image que le dépôt rtgre construit, signe et publie. Ce dépôt la référence par son empreinte : une modification du site n'est donc en ligne qu'une fois la nouvelle empreinte fusionnée ici, puis la génération suivante passée.

Cette fusion était confiée à Renovate, avec fusion automatique. Du 21 au 28 novembre 2026, il n'en a fait aucune, et les quatre mises en ligne du site ont été faites à la main :

- **Renovate passe quand il le décide.** C'est un service hébergé : une image publiée le 23 novembre à 22 h 45 UTC n'a été proposée que le 26 à 2 h 24 UTC, 51 heures plus tard. Les autres fois, il n'a réagi vite que parce qu'une pull request manuelle venait de le réveiller.
- **Il ne fusionne pas ce qu'il propose.** Sa proposition du 26 novembre, tous contrôles verts, est restée ouverte 26 heures. La fusion automatique de GitHub n'est pas activée sur ce dépôt : Renovate doit repasser pour fusionner, et il ne repasse pas.
- **Un contrôle rouge l'arrête**, même sans rapport avec l'image du site.

Une fois l'empreinte fusionnée, il restait à attendre la génération horaire, jusqu'à une heure.

Les contraintes ne changent pas : `main` n'accepte que des pull requests aux commits signés et aux contrôles verts, le cluster ne lance qu'une image signée et référencée par son empreinte, et aucun secret de ce dépôt ne doit permettre d'y écrire depuis un autre.

## Options envisagées

### Garder Renovate et activer la fusion automatique de GitHub

Un réglage du dépôt, et Renovate n'aurait plus à repasser pour fusionner. Mais il resterait seul à décider du moment où il voit une nouvelle image : le délai de 51 heures ne dépend pas de ce dépôt. GitHub ne fusionnerait en outre que sur les contrôles obligatoires, qui ne comprennent pas la vérification de la signature.

### Référencer l'image par son tag, sans empreinte

Chaque génération prendrait la dernière image, sans rien fusionner. Le cluster vérifierait encore sa signature. Mais Git ne dirait plus ce qui tourne, un retour en arrière ne serait plus un simple revert, et une image ne passerait plus par les contrôles de ce dépôt.

### Un outil du cluster qui suit le registre

Argo CD Image Updater surveille un registre et met à jour l'application. Soit il le fait sans passer par Git, et le dépôt ne décrit plus le cluster. Soit il écrit dans Git, donc directement sur `main`, ce que la protection de la branche interdit. C'est aussi un composant de plus sur un nœud de 6 Go.

### Interroger le registre à intervalle régulier

Un workflow de ce dépôt qui regarde le registre toutes les quinze minutes, lancé par le minuteur de la sonde ([ADR 0027](0027-lancer-la-sonde-exterieure-par-un-minuteur.md)). Aucun droit à donner à l'autre dépôt. Mais une attente de quinze minutes au pire, et une mise en ligne accrochée au mécanisme de la surveillance.

### Un workflow de ce dépôt, déclenché par celui qui publie

Le workflow qui publie l'image lance, à la fin, un workflow de ce dépôt. Celui-ci lit l'empreinte dans le registre, vérifie sa signature, ouvre une pull request, attend ses contrôles et la fusionne. La mise en ligne suit la publication de quelques minutes, par le même chemin qu'une modification faite à la main.

## Décision

Le workflow `Promote` de ce dépôt met en ligne l'image du site, et le workflow `Image` du dépôt rtgre le déclenche après avoir publié et signé l'image. Renovate ne propose plus cette image.

- **Le déclencheur ne transmet rien.** `Promote` ne reçoit ni empreinte ni nom d'image : il lit dans le registre l'empreinte que porte le tag, et ne la retient que si elle est signée par l'identité de [`signed-images.txt`](../../kubernetes/kyverno/files/signed-images.txt). Celui qui peut déclencher ne peut ni choisir une image, ni revenir à une ancienne.
- **Deux applications GitHub, un droit chacune.** Celle du dépôt rtgre ne peut que lancer des workflows ici. Celle de ce dépôt ne peut qu'y écrire une branche et y gérer une pull request, et sa clé ne sort pas d'ici. Une pull request ouverte par une application lance les contrôles, ce qu'une pull request ouverte avec le jeton d'un workflow ne fait pas.
- **Les clés ne se lisent que depuis `main`**, par un environnement dans chaque dépôt : `promotion` ici, `platform` dans rtgre.
- **Tous les contrôles avant la fusion**, pas seulement les obligatoires : `Quality`, `Kubernetes` (dont la signature) et `Security`. Un contrôle en échec est relancé une fois, pour ne pas buter sur un registre qui refuse une lecture.
- **Le commit est signé par GitHub**, parce qu'il est créé par l'API au nom de l'application.
- **Le site est généré dès le déploiement** : un crochet `PostSync` d'Argo CD lance une génération à la fin de la synchronisation ([`kubernetes/rtgre`](../../kubernetes/rtgre)), sans attendre la génération horaire.

## Conséquences

- Une modification fusionnée dans rtgre est en ligne sans intervention, en une dizaine de minutes : 9 minutes 54 secondes au premier essai, le 28 novembre 2026. Argo CD en prend la plus grande part, de quelques secondes à quatre minutes : il relit le dépôt à son rythme.
- **Les deux applications et leurs clés ne vivent pas dans le dépôt** : ce sont des réglages de GitHub. Le [runbook](../runbooks/suivre-une-mise-en-ligne-du-site.md) dit comment les recréer et renouveler leurs clés.
- **Sans elles, rien ne casse** : l'image est publiée, et la mise en ligne redevient manuelle.
- **Un contrôle rouge sans rapport bloque la mise en ligne**, par exemple une vulnérabilité publiée dans une autre image. C'est voulu : la pull request reste ouverte, le workflow `Image` de rtgre échoue et prévient son auteur, et le runbook dit comment trancher.
- Une promotion qui attend son tour est remplacée par la suivante : après deux publications rapprochées, seule la dernière image est mise en ligne.
- Argo CD n'est pas prévenu de la fusion : il relit le dépôt à son rythme. Le prévenir demanderait de l'exposer à GitHub, ce que l'[ADR 0010](0010-deployer-en-gitops-avec-argo-cd.md) écarte.
- Renovate continue de proposer toutes les autres dépendances.
